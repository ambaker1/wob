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
    namespace export exitMainLoop; # Exit main loop programmatically
    namespace export widget; # Widget class
    namespace export closeAllWidgets; # Close all widgets
}

# mainLoop --
#
# Enter the Tcl/Tk event loop, with an interactive command line.
# Values or codes can be returned to caller with "return"
#
# Syntax:
# mainLoop <$onBlank>
# 
# Arguments:
# onBlank:      Default "continue" ignores blank lines. "break" exits event loop

proc ::wob::mainLoop {{onBlank continue}} {
    variable userInput
    variable userInputComplete
    if {$onBlank ni {continue break}} {
        return -code error "wrong option: want \"continue\" or \"break\""
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
        if {$userInputComplete == 1} {
            # User input
            set code [catch {uplevel 1 $userInput} result options]
        }
        if {$userInputComplete == -1} {
            # "exitMainLoop" called (interactive or scripted)
            set code [catch {uplevel 1 $userInput} result options]
        }
        # Evaluate user input, but catch for error or other return codes
        switch $code {
            0 { # Success. 
                if {[string trim $userInput] eq ""} {$onBlank}
                if {$result ne ""} {puts $result}
            }
            1 { # Error. Print the error message, do not pass error
                puts [dict get $options -errorinfo]
            }
            2 { # Return, return to caller
                # Lower the level of a return code (to account for this level)
                if {[dict get $options -code] == 2} {
                    dict incr options -level -1
                }
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
        set userInputComplete 1
    }
    return
}

# exitMainLoop --
# 
# Used to programmatically return from mainLoop without going through stdin
#
# Syntax:
# exitMainLoop <$arg ...>
#
# Arguments:
# arg ...       Arguments to append to "return"

proc ::wob::exitMainLoop {args} {
    variable userInput [list return {*}$args]
    variable userInputComplete
    if {$userInputComplete == 0} {
        # For programmatically exiting
        puts $userInput
    }
    set userInputComplete -1; # Trigger exit
    return
}

# widget --
# 
# TclOO object used for creating GUIs within their own Tcl interpreter.
#
# Syntax:
# widget new <$title>
#
# Arguments:
# title:        Window title for widget. Default "Widget"

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
################################################################################

# eval --
# 
# Evaluate code in the widget interpreter, and handle window closing error
#
# Syntax:
# $widget eval $arg ...
#
# Arguments:
# widget        Widget object name
# $arg ...      Code to evaluate in widget interpreter.

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

# alias --
#
# Create an alias command in the widget interpreter to interface with the
# main Tcl interpreter.
#
# Syntax:
# $widget alias $srcCmd $targetCmd <$arg ...>
#
# Arguments:
# widget        Widget object name
# srcCmd        Command in source interpreter
# targetCmd     Command in widget interpreter
# arg ...       Additional arguments to prepend to $targetCmd

method alias {srcCmd targetCmd args} {
    $interp alias $srcCmd $targetCmd {*}$args
}

# vlink --
#
# Link a variable in the parent interpreter to one in the child interpreter
# Must be 
#
# Syntax:
# $widget vlink $srcVar $targetVar
#
# Arguments:
# widget        Widget object name
# srcVar        Variable in source interpreter
# targetVar     Variable in widget interpreter

method vlink {srcVar targetVar} {
    upvar 1 $srcVar var
    # Create traces that link the variable to the widget
    set ns [self namespace]
    trace add variable var read [list ${ns}::my ReadTrace $targetVar]
    trace add variable var write [list ${ns}::my WriteTrace $targetVar]
    trace add variable var unset [list ${ns}::my UnsetTrace $targetVar]
    return
}

# Private methods for vlink variable traces

method WriteTrace {targetVar srcVar key op} {
    upvar 1 $srcVar var
    if {[array exists var]} {
        my set ${targetVar}($key) $var($key)
    } else {
        my set $targetVar $var
    }
}

method ReadTrace {targetVar srcVar key op} {
    upvar 1 $srcVar var
    # Unset the srcVar if the targetVar was unset.
    if {![my eval [list info exists $targetVar]]} {
        unset var
        return
    }
    if {[array exists var]} {
        # Unset the specific var/key combo if it does not exist in widget
        if {![my eval [list info exists ${targetVar}($key)]]} {
            unset var($key)
        } else {
            set var($key) [my get ${targetVar}($key)]
        }
    } else {
        set var [my get $targetVar]
    }
}

method UnsetTrace {targetVar srcVar key op} {
    upvar 1 $srcVar var
    if {[array exists var]} {
        my eval [list unset ${targetVar}($key)]
    } else {
        my eval [list unset $targetVar]
    }
}

# interp --
#
# Get the interpreter name (for advanced introspection)
#
# Syntax:
# $widget interp
#
# Arguments:
# widget        Widget object name

method interp {} {
    return $interp
}

# Short-hand variable access methods
################################################################################

# set --
# 
# Set the value of a variable in a widget
#
# Syntax:
# $widget set $varName $value
#
# Arguments:
# widget        Widget object name
# varName       Variable name in widget interpreter
# value         Value to set

method set {varName value} {
    my eval [list set $varName $value]
}

# $widget get --
# 
# Get the value of a variable in a widget
#
# Syntax:
# $widget set $varName $value
#
# Arguments:
# widget        Widget object name
# varName       Variable name in widget interpreter
# value         Value to set

method get {varName} {
    my eval [list set $varName]
}

}; # end of class definition

# closeAllWidgets --
#
# Close all widgets

proc ::wob::closeAllWidgets {} {
    foreach widget [info class instances ::wob::widget] {
        $widget destroy
    }
    return
}

# Finally, provide the package
package provide wob 0.2
 
