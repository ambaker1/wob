package require tin 1.0
set dir [tin mkdir -force wob 1.0.1]
file copy README.md $dir 
file copy LICENSE $dir 
file copy wob.tcl $dir 
file copy pkgIndex.tcl $dir
