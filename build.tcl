set wob_version 0.2
package require tin 0.6
set config ""
dict set config VERSION $wob_version
tin bake src build $config

# Test wob (this is a manual test)
source build/wob.tcl
namespace import wob::*

# Test 1 (get open file, verify that it prints the right thing to command line)
set widget [widget new]
set filename [$widget eval tk_getOpenFile]
$widget destroy
puts $filename

# Test 2 (basic prompt, menu selection
set widget [widget new]
$widget eval {
wm minsize . 250 50
label .label -text "Choose analysis type:"
tk_optionMenu .options AnalysisType "" Pushover Dynamic
pack .label -side top -fill x
pack .options -side bottom -fill x
vwait AnalysisType
}
puts [$widget get AnalysisType]
$widget destroy

# Test 3 (Manipulate clipboard (can paste hello world into mainLoop))
set widget [widget new]
$widget set text "hello world"
$widget eval {
	clipboard clear
	clipboard append $text
}
mainLoop; # Use "return" to continue
catch {$widget destroy}

# Test 3: Basic stopwatch
# Code borrowed from https://wiki.tcl-lang.org/page/A+little+stopwatch
set stopwatch [widget new]
$stopwatch eval {
    #! /usr/bin/tclsh
    package require Tk
    option add *Button.padY 0        ;# to make it look better on Windows
    option add *Button.borderWidth 1
    #---------------------------------------------------- testing i18n
    package require msgcat
    namespace import msgcat::mc msgcat::mcset
    mcset de Start Los
    mcset de Stop  Halt
    mcset de Zero  Null
    mcset fr Start Allez
    mcset fr Stop  Arrêtez
    mcset fr Zero  ???
    mcset zh Start \u8DD1
    mcset zh Stop  \u505C
    mcset zh Zero  ???
    msgcat::mclocale en ;# edit this line for display language
    #--------------------------------------------------------------- UI
    button .start -text [mc Start] -command Start
    label  .time -textvar time -width 9 -bg black -fg yellow -font "Sans 20"
    set time 00:00.00
    button .stop -text [mc Stop] -command Stop
    button .zero -text [mc Zero] -command Zero
    set state 0
    bind . <Key-space> {
        if {$state} {.stop invoke
        } else {
            .start invoke
        }
    }
    bind . <Key-0> {
        .zero invoke
    }
    eval pack [winfo children .] -side left -fill y
    #------------------------------------------------------- procedures
    proc every {ms body} {eval $body; after $ms [namespace code [info level 0]]}

    proc Start {} {
        if {$::time eq {00:00.00}} {
            set ::time0 [clock clicks -milliseconds]
        }
        every 20 {
            set m [expr {[clock clicks -milliseconds] - $::time0}]
            set ::time [format %2.2d:%2.2d.%2.2d \
                [expr {$m/60000}] [expr {($m/1000)%60}] [expr {$m%1000/10}]]
            incr ::titleskip
            if {$::titleskip >= 12} {
                wm title . "Timer $::time"
                set ::titleskip 0
            }
        }
        .start config -state disabled
        set ::state 1
    }
    proc Stop {} {
        if {[llength [after info]]} {
            after cancel [after info]
        }
        .start config -state normal
        set ::state 0
    }
    proc Zero {} {
        set ::time 00:00.00
        set ::time0 [clock clicks -milliseconds]
    }
}
mainLoop; # Use "return" to continue
catch {$stopwatch destroy}

# Everything ok?
puts "Update main files and install? (Y/N)"
set result [gets stdin]
if {$result eq "Y"} {
    file copy -force {*}[glob -directory build *] [pwd]
    tin bake doc/template/version.tin doc/template/version.tex $config
    source install.tcl
}