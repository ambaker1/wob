# wob.tcl
################################################################################
# Widget objects with separate Tcl interpreters

# Copyright (C) 2023 Alex Baker, ambaker1@mtu.edu
# All rights reserved. 

# See the file "LICENSE" for information on usage, redistribution, and for a 
# DISCLAIMER OF ALL WARRANTIES.
################################################################################

# Define namespace
namespace eval ::wob { 
    variable userInput
    variable userInputComplete
    namespace export mainLoop; # Enter event loop, with user input
    namespace export widget; # Widget class
}

# mainLoop --
#
# Enter the Tcl/Tk event loop, with an interactive command line.
# Values or codes can be returned to caller with "return"
# 
# Arguments:
# onBlank:      "continue" to ignore blank lines, "break" to exit event loop

proc ::wob::mainLoop {{onBlank continue}} {
    variable userInput
    variable userInputComplete
    if {$onBlank ni {continue break}} {
        return -code error "Unknown option. Try \"continue\" or \"break\""
    }
    # Set up file event for user input
    set oldFileEvent [fileevent stdin readable]
    fileevent stdin readable ::wob::GetUserInput
    while {1} {
        # Initialize
        set userInput ""
        set userInputComplete 0
        puts -nonewline "> " 
        flush stdout; # For normal Tcl
        # Wait for user input
        vwait ::wob::userInputComplete
        # Evaluate user input, but catch for error or other return codes
        switch [catch {uplevel 1 $userInput} result options] {
            0 { # Success. 
                if {[string trim $userInput] eq ""} {$onBlank}
                if {$result ne ""} {puts $result}
            }
            1 { # Error. Print the error message, do not pass error
                puts [dict get $options -errorinfo]
            }
            2 { # Return to caller
                break
            }
            3 { # Break, throw warning
                puts "invoked \"break\" outside of a loop"
            }
            4 { # Continue, throw warning
                puts "invoked \"continue\" outside of a loop"
            }
        }
    }
    # Restore old file event and return user specified code and result
    fileevent stdin readable $oldFileEvent
    return -options $options $result
}

# GetUserInput --
#
# File-event on stdin to get user input. Uses userInputComplete for vwait

proc ::wob::GetUserInput {} {
    variable userInput
    variable userInputComplete
    # Get user input
    append userInput "[gets stdin]\n"
    if {[info complete $userInput]} {
        set userInputComplete true
    }
    return
}

# widget --
# 
# TclOO object used for creating GUIs within their own Tcl interpreter.

oo::class create ::wob::widget {
    # Make $interp available in all methods
    variable interp
    
    # Define constructor (load Tk, setup widget)
    # Arguments:
    # title:        Title for window. Default Widget.
    constructor {{title Widget}} {
        # Create unique interpreter
        set interp [interp create]
        # Create widget window
        $interp eval {package require Tk}
        $interp eval [list wm title . $title]
        # Configure "exit" to destroy the widget
        # This modified "exit" command does not have the option for return code.
        $interp alias exit [self] destroy
        # Bind window "Destroy" event to call exit alias
        $interp eval {
            bind . <Destroy> {
                if {"%W" == [winfo toplevel %W]} {
                    exit
                }
            }
        }
        return
    }
    
    # Bind destruction of object to deletion of interpreter
    destructor {
        if {[interp exists $interp]} {
            interp cancel -unwind $interp
            interp delete $interp
        }
    }
    
    # Basic methods
    ########################################################################
    
    # $widget eval --
    # 
    # Evaluate code in the widget interpreter, and handle window closing error
    
    method eval {args} {
        set code [catch {$interp eval {*}$args} result options]
        # Handle case where user closed window (return nothing)
        if {$code == 1} {
            set errorCode [lrange [dict get $options -errorcode] 0 end-1]
            if {$errorCode eq {TCL CANCEL IUNWIND}} {
                return
            }
        }
        # Normally, just return the result of eval
        return {*}$options $result
    }
    
    # $widget alias --
    #
    # Create an alias command in the widget interpreter to interface with the
    # main Tcl interpreter.
    
    method alias {srcCmd targetCmd args} {
        $interp alias $srcCmd $targetCmd {*}$args
    }
    
    # $widget interp
    #
    # Get the interpreter name (for advanced introspection)
    
    method interp {} {
        return $interp
    }

    # Short-hand variable access methods
    ########################################################################
    
    # $widget set --
    # 
    # Set the value of a variable in a widget
    
    method set {varName value} {
        my eval [list set $varName $value]
    }
    
    # $widget get --
    # 
    # Get the value of a variable in a widget
    method get {varName} {
        my eval [list set $varName]
    }
}

# Finally, provide the package
package provide wob 0.1.1
