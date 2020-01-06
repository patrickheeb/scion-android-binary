package main

import (
	"os"

	beacon_srv "github.com/scionproto/scion/go/beacon_srv"
	border "github.com/scionproto/scion/go/border"
	cert_srv "github.com/scionproto/scion/go/cert_srv"
	godispatcher "github.com/scionproto/scion/go/godispatcher"
	logdog "github.com/scionproto/scion/go/tools/logdog"
	path_srv "github.com/scionproto/scion/go/path_srv"
	scion_custpk_load "github.com/scionproto/scion/go/tools/scion-custpk-load"
	sciond "github.com/scionproto/scion/go/sciond"
	scion_pki "github.com/scionproto/scion/go/tools/scion-pki"
	scmp "github.com/scionproto/scion/go/tools/scmp"
	showpaths "github.com/scionproto/scion/go/tools/showpaths"
	sig "github.com/scionproto/scion/go/sig"
)

func main() {
	usage := "Please supply a SCION binary as the first argument.\nValid binaries include: beacon_srv border cert_srv godispatcher logdog path_srv scion-custpk-load sciond scion-pki scmp showpaths sig\n"
	if len(os.Args) < 2 {
		os.Stderr.WriteString(usage)
		os.Exit(1)
	}
	binary := os.Args[1]
	os.Args = append(os.Args[:1], os.Args[2:]...)

	switch binary {
	case "beacon_srv":
		beacon_srv.AndroidMain()
	case "border":
		border.AndroidMain()
	case "cert_srv":
		cert_srv.AndroidMain()
	case "godispatcher":
		godispatcher.AndroidMain()
	case "logdog":
		logdog.AndroidMain()
	case "path_srv":
		path_srv.AndroidMain()
	case "scion-custpk-load":
		scion_custpk_load.AndroidMain()
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
	default:
		os.Stderr.WriteString(usage)
		os.Exit(1)
	}
}