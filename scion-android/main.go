package main

import (
	"os"

	border "github.com/scionproto/scion/go/border"
	cs "github.com/scionproto/scion/go/cs"
	godispatcher "github.com/scionproto/scion/go/godispatcher"
	logdog "github.com/scionproto/scion/go/tools/logdog"
	sciond "github.com/scionproto/scion/go/sciond"
	scion_pki "github.com/scionproto/scion/go/tools/scion-pki"
	scmp "github.com/scionproto/scion/go/tools/scmp"
	showpaths "github.com/scionproto/scion/go/tools/showpaths"
	sig "github.com/scionproto/scion/go/sig"
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
	case "godispatcher":
		godispatcher.AndroidMain()
	case "logdog":
		logdog.AndroidMain()
	case "sciond":
		sciond.AndroidMain()
	case "scion-pki":
		scion_pki.AndroidMain()
	case "scmp":
		scmp.AndroidMain()
	case "showpaths":
		showpaths.AndroidMain()
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