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
    variable interactive 0; # Whether main loop is active
    # Tcl/Tk Event Loop
    namespace export mainLoop; # Enter event loop, with user input
    namespace export exitMainLoop; # Exit main loop programmatically
    # Widget Objects
    namespace export widget; # Widget class
    namespace export closeAllWidgets; # Close all widgets
}

# mainLoop --
#
# Enter the Tcl/Tk event loop, with an interactive command line.
# Values or codes can be returned to caller with "return", or "exitMainLoop"
#
# Syntax:
# mainLoop <$onBlank>
# 
# Arguments:
# onBlank:      Default "continue" ignores blank lines. "break" exits event loop

proc ::wob::mainLoop {{onBlank continue}} {
    variable userInput
    variable userInputComplete
    variable interactive
    # Validate input
    if {$onBlank ni {continue break}} {
        return -code error "wrong option: want \"continue\" or \"break\""
    }
    # Enter interactive mainLoop
    set oldFileEvent [fileevent stdin readable]; # Save old file event
    set oldInteractive $interactive; # Save old "interactive" status
    fileevent stdin readable ::wob::GetUserInput; # File event for user input
    set interactive 1
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
    # Exit interactive mainLoop
    fileevent stdin readable $oldFileEvent; # Restore old file event
    set interactive $oldInteractive
    # Return user specified code and result
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

# upvar --
#
# Link a variable in the parent interpreter to one in the child interpreter
# Initializes srcVar (and myVar) as blank if it does not exist.
#
# Syntax:
# $widget upvar $srcVar $myVar <$srcVar $myVar ...>
#
# Arguments:
# widget        Widget object name
# srcVar        Variable in source interpreter (must be scalar or array element)
# myVar         Variable in widget interpreter (must be scalar or array element)

method upvar {srcVar myVar args} {
    # Check arity
    if {[llength $args] % 2 == 1} {
        return -code error "wrong # args: should be\
                \"widget upvar srcVar myVar ?srcVar myVar ...?\"" 
    }
    upvar 1 $srcVar var
    # Ensure that srcVar is scalar (or array element)
    if {![info exists var]} {
        set var ""; 
    } elseif {[array exists var]} {
        return -code error "srcVar cannot be array"
    }
    # Ensure that myVar is not array (throw error if the case)
    if {[my eval [list info exists $myVar]]} {
        if {[my eval [list array exists $myVar]]} {
            return -code error "myVar cannot be array"
        }
    }
    # Initialize targetVar and traces that link the variable to the widget
    my set $myVar $var
    ::wob::Unlink var [self] $myVar; # Prevent duplicate traces
    trace add variable var read [list ::wob::ReadTrace [self] $myVar]
    trace add variable var write [list ::wob::WriteTrace [self] $myVar]
    trace add variable var unset [list ::wob::UnsetTrace [self] $myVar]
    # Tail recursion
    if {[llength $args] > 0} {
        tailcall my upvar {*}$args
    }
    return
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

# Private procs for upvar method variable traces

# Unlink --
#
# Unlinks srcVar and targetVar from a widget
#
# Syntax:
# Unlink $srcVar $widget $targetVar
#
# Arguments:
# srcVar        Variable in source interpreter (must be scalar or array element)
# widget        Widget object name
# targetVar     Variable in widget interpreter (must be scalar or array element)

proc ::wob::Unlink {srcVar widget targetVar} {
    upvar 1 $srcVar var
    trace remove variable var read [list ::wob::ReadTrace $widget $targetVar]
    trace remove variable var write [list ::wob::WriteTrace $widget $targetVar]
    trace remove variable var unset [list ::wob::UnsetTrace $widget $targetVar]
}

# WriteTrace --
#
# Variable trace on variable in parent interpreter that also sets corresponding
# variable in the widget interpreter on write.
#
# Syntax:
# WriteTrace $widget $targetVar $name1 $name2
#
# Arguments:
# widget        Widget object name
# targetVar     Variable name in widget interpreter
# name1         Variable name in parent interpreter
# name2         Array key name if name1 is array.

proc ::wob::WriteTrace {widget targetVar name1 name2 args} {
    upvar 1 $name1 var
    # Unlink variable if $widget no longer exists.
    if {![info object isa object $widget]} {
        if {[array exists var]} {
            Unlink var($name2) $widget $targetVar
        } else {
            Unlink var $widget $targetVar
        }
        return
    }
    if {[array exists var]} {
        $widget set $targetVar $var($name2)
    } else {
        $widget set $targetVar $var
    }
}

# ReadTrace --
# 
# Variable trace on variable in parent interpreter that retrieves value from
# corresponding variable in the widget interpreter on read.
#
# Syntax:
# ReadTrace $widget $targetVar $name1 $name2
#
# Arguments:
# widget        Widget object name
# targetVar     Variable name in widget interpreter
# name1         Variable name in parent interpreter
# name2         Array key name if name1 is array.

proc ::wob::ReadTrace {widget targetVar name1 name2 args} {
    upvar 1 $name1 var
    # Unlink variable if $widget no longer exists.
    if {![info object isa object $widget]} {
        if {[array exists var]} {
            Unlink var($name2) $widget $targetVar
        } else {
            Unlink var $widget $targetVar
        }
        return
    }
    # Unset the srcVar if the targetVar was unset.
    if {![$widget eval [list info exists $targetVar]]} {
        if {[array exists var]} {
            unset var($name2)
        } else {
            unset var
        }
        return
    }
    # Set the srcVar to the current value of the targetVar
    if {[array exists var]} {
        set var($name2) [$widget get $targetVar]
    } else {
        set var [$widget get $targetVar]
    }
}

# UnsetTrace --
# 
# Variable trace on variable in parent interpreter that unsets the corresponding
# variable in the widget interpreter on unset.
#
# Syntax:
# UnsetTrace $widget $targetVar
#
# Arguments:
# widget        Widget object name
# targetVar     Variable name in widget interpreter

proc ::wob::UnsetTrace {widget targetVar args} {
    $widget eval [list unset $targetVar]
}

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
package provide wob 1.1
 
