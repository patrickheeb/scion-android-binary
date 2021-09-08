package main

import (
	"os"

	cs "github.com/scionproto/scion/go/cs"
	dispatcher "github.com/scionproto/scion/go/dispatcher"
	sig "github.com/scionproto/scion/go/posix-gateway"
	border "github.com/scionproto/scion/go/posix-router"
	scion "github.com/scionproto/scion/go/scion"
	scion_pki "github.com/scionproto/scion/go/scion-pki"
	sciond "github.com/scionproto/scion/go/sciond"
)

func main() {
	usage := "Please supply a SCION binary as the first argument.\nValid binaries include: border cs godispatcher logdog scion-custpk-load sciond scion-pki scmp showpaths sig sensorfetcher sensorserver\n"
	if len(os.Args) < 2 {
		os.Stderr.WriteString(usage)
		os.Exit(1)
	}
	binary := os.Args[1]
	os.Args = append(os.Args[:1], os.Args[2:]...)

	switch binary {
	case "border":
		border.AndroidMain()
	case "cs":
		cs.AndroidMain()
	case "dispatcher":
		dispatcher.AndroidMain()
	case "sciond":
		sciond.AndroidMain()
	case "scion-pki":
		scion_pki.AndroidMain()
	case "scion":
		scion.AndroidMain()
	case "sig":
		sig.AndroidMain()
	case "sensorfetcher":
		Sensorfetcher()
	case "sensorserver":
		Sensorserver()
	default:
		os.Stderr.WriteString(usage)
		os.Exit(1)
	}
}
