if {![package vsatisfies [package provide Tcl] 8.6]} {return}
package ifneeded wob 1.1a0 [list source [file join $dir wob.tcl]]
