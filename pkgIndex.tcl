if {![package vsatisfies [package provide Tcl] 8.6]} {return}
package ifneeded wob 0.2.4 [list source [file join $dir wob.tcl]]
