package main

import (
	"bytes"
	"context"
	"fmt"
	"io"
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

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// a workload can have several SPIFFE IDs; this will select the ID set in
	// the SERVER_SPIFFE_ID environment variable.
	// NB in our example, the server will have the IDs:
	//		spiffe://spire.test/user-0
	//		spiffe://spire.test/example-server
	var svidPicker func([]*x509svid.SVID) *x509svid.SVID
	serverID := os.Getenv("SERVER_SPIFFE_ID")
	if serverID != "" {
		svid, err := spiffeid.FromString(serverID)
		if err != nil {
			log.Fatalf("failed to parse the SERVER_SPIFFE_ID environment variable: %v", err)
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

	// configure the HTTP server with SPIFFE managed TLS certificates.
	server := &http.Server{
		TLSConfig: tlsconfig.MTLSServerConfig(source, source, tlsconfig.AuthorizeAny()),
	}

	// stop the HTTP server when this process is interrupted.
	go func() {
		signalCh := make(chan os.Signal, 1)
		signal.Notify(signalCh, os.Interrupt)
		<-signalCh
		server.Shutdown(context.Background())
	}()

	// define the example service handler. it will show the server and
	// client SVID details.
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		var result bytes.Buffer
		clientCertificate := r.TLS.PeerCertificates[0]
		clientID, err := x509svid.IDFromCert(clientCertificate)
		if err != nil {
			fmt.Fprintf(&result, "Failed to SPIFFE ID from client certificate: %v\n", err)
		} else {
			fmt.Fprintf(&result, "Client SPIFFE ID: %s\n", clientID)
		}
		clientCertificateText, err := getCertificateText(clientCertificate.Raw)
		if err != nil {
			fmt.Fprintf(&result, "Failed to get client certificate text: %v\n", err)
		} else {
			fmt.Fprintf(&result, "Client %s\n", clientCertificateText)
		}
		log.Printf("Request received. Result:\n%s", result.String())
		_, _ = io.WriteString(w, result.String())
	})

	// run the HTTP server.
	if err := server.ListenAndServeTLS("", ""); err != http.ErrServerClosed {
		log.Fatalf("Failed to run: %v", err)
	}
	log.Println("Bye bye")
}
