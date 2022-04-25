package main

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/exec"
	"os/signal"

	"github.com/spiffe/go-spiffe/v2/logger"
	"github.com/spiffe/go-spiffe/v2/spiffeid"
	"github.com/spiffe/go-spiffe/v2/spiffetls/tlsconfig"
	"github.com/spiffe/go-spiffe/v2/svid/x509svid"
	"github.com/spiffe/go-spiffe/v2/workloadapi"
)

func getCertificateText(der []byte) (string, error) {
	cmd := exec.Command("openssl", "x509", "-text", "-inform", "der")
	cmd.Stdin = bytes.NewReader(der)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return "", err
	}
	return string(output), nil
}

func callServer(source *workloadapi.X509Source) string {
	serverURL := "https://server"
	serverID := spiffeid.RequireFromString("spiffe://spire.test/example-server")

	// configure mTLS between this workload and the serverID workload.
	tlsConfig := tlsconfig.MTLSClientConfig(source, source, tlsconfig.AuthorizeID(serverID))
	client := &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: tlsConfig,
		},
	}

	// call the server.
	r, err := client.Get(serverURL)
	if err != nil {
		return fmt.Sprintf("Error connecting to %q: %v", serverURL, err)
	}
	defer r.Body.Close()

	// read the response body.
	body, err := ioutil.ReadAll(r.Body)
	if err != nil {
		return fmt.Sprintf("Unable to read body: %v", err)
	}

	// get the server SPIFFE ID and certificate.
	var result bytes.Buffer
	serverCertificate := r.TLS.PeerCertificates[0]
	serverSpiffeID, err := x509svid.IDFromCert(serverCertificate)
	if err != nil {
		fmt.Fprintf(&result, "Failed to SPIFFE ID from server certificate: %v\n", err)
	} else {
		fmt.Fprintf(&result, "Server SPIFFE ID: %s\n", serverSpiffeID)
	}
	clientCertificateText, err := getCertificateText(serverCertificate.Raw)
	if err != nil {
		fmt.Fprintf(&result, "Failed to get server certificate text: %v\n", err)
	} else {
		fmt.Fprintf(&result, "Server %s\n", clientCertificateText)
	}
	fmt.Fprintf(&result, "%s\n", body)

	return result.String()
}

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// a workload can have several SPIFFE IDs; this will select the ID set in
	// the CLIENT_SPIFFE_ID environment variable.
	// NB in our example, the server will have the IDs:
	//		spiffe://spire.test/user-0
	//		spiffe://spire.test/example-client
	var svidPicker func([]*x509svid.SVID) *x509svid.SVID
	clientID := os.Getenv("CLIENT_SPIFFE_ID")
	if clientID != "" {
		svid, err := spiffeid.FromString(clientID)
		if err != nil {
			log.Fatalf("failed to parse the CLIENT_SPIFFE_ID environment variable: %v", err)
		}
		svidPicker = func(svids []*x509svid.SVID) *x509svid.SVID {
			for _, id := range svids {
				if id.ID == svid {
					return id
				}
			}
			return nil
		}
	}

	// create a source of TLS certificates. these are SPIFFE managed by
	// the local Workload API Server (e.g. spire-agent).
	// NB The Workload API socket path is defined by the
	//    SPIFFE_ENDPOINT_SOCKET environment variable.
	source, err := workloadapi.NewX509Source(
		ctx,
		workloadapi.WithClientOptions(workloadapi.WithLogger(logger.Std)),
		workloadapi.WithDefaultX509SVIDPicker(svidPicker))
	if err != nil {
		log.Fatalf("Unable to create X509Source: %v", err)
	}
	defer source.Close()

	// configure the HTTP server.
	server := &http.Server{}

	// stop the HTTP server when this process is interrupted.
	go func() {
		signalCh := make(chan os.Signal, 1)
		signal.Notify(signalCh, os.Interrupt)
		<-signalCh
		server.Shutdown(context.Background())
	}()

	// define the example service handler. it will connect to the server and
	// dump its HTTP response body.
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		result := callServer(source)
		_, _ = io.WriteString(w, result)
	})

	// run the HTTP server.
	if err := server.ListenAndServe(); err != http.ErrServerClosed {
		log.Fatalf("Failed to run: %v", err)
	}
	log.Println("Bye bye")
}
