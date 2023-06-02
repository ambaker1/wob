set wob_version 0.2.1
package require tin 0.6
set config ""
dict set config VERSION $wob_version
tin bake src build $config

# Test wob (this is a manual test)
set dir build
source build/pkgIndex.tcl
tin import wob -exact $wob_version
tin import tcltest

# Ensure that widgets are initialized properly
test widget {
    # Ensures that the "title" argument works
} -body {
    set widget [widget new foo]
    $widget eval {wm title .}
} -result {foo}
$widget destroy

# create and close widgets
test createWidgets {
    # Create widgets
} -body {
    set w1 [widget new]
    set w2 [widget new]
    set w3 [widget new]
    llength [info class instances ::wob::widget]
} -result {3}

test closeAllWidgets {
    # Close all widgets
} -body {
    closeAllWidgets
    llength [info class instances ::wob::widget]
} -result {0}

test mainLoop_scope {
    # Ensure that the mainLoop userInput is being executed in the proper scope
} -body {
    set x 0
    after idle {
        puts ""
        set ::wob::userInput "set x 1"
        set ::wob::userInputComplete 1
        after idle exitMainLoop
    }
    mainLoop
    set x
} -result {1}

test mainLoop_no_nest {
    # Ensure that a mainLoop cannot be called within a mainLoop
} -body {
    set result ""
    after idle {
        puts ""
        set ::wob::userInput "catch {mainLoop} result"
        set ::wob::userInputComplete 1
        after idle exitMainLoop
    }
    mainLoop
    set result
} -result {already in mainLoop}

# Test out exitMainLoop
test exitMainLoop_1 {
    # Try out mainLoop and exitMainLoop
} -body {
    after idle {exitMainLoop}
    mainLoop
} -result {}

test exitMainLoop_2 {
    # Advanced applications of exitMainLoop
} -body {
    set result ""; # initialize
    # Return value
    after idle {exitMainLoop foo}
    while {1} {
        lappend result [mainLoop]
        after idle {exitMainLoop -code break}; # Return break
    }
    # Return "return"
    proc foo {} {
        mainLoop
        return
    }
    after idle {exitMainLoop -code return bar}
    lappend result [foo]
    set result
} -result {foo bar}

test widget_vlink_write_ss {
    # write variable (scalar to scalar link)
} -body {
    set widget [widget new]
    $widget vlink x x
    set x 10
    $widget get x
} -result {10}

test widget_vlink_read_ss {
    # read variable (scalar to scalar link)
} -body {
    $widget set x 5
    set x
} -result {5}

test widget_vlink_unset_ss1 {
    # unset variable (scalar to scalar link) (from parent)
} -body {
    unset x
    $widget eval info exists x
} -result {0}

test widget_vlink_unset_ss2 {
    # unset variable (scalar to scalar link) (from widget)
} -body {
    $widget vlink x x
    set x 5
    $widget eval {unset x}
    info exists x
} -result {0}

test widget_vlink_write_se {
    # write variable (scalar to array element link)
} -body {
    $widget vlink foo x(1)
    $widget vlink bar x(2)
    set foo "hello "
    set bar "world"
    $widget eval {string cat $x(1) $x(2)}
} -result {hello world}

test widget_vlink_read_se {
    # read variable (scalar to array element link)
} -body {
    $widget set x(1) "goodbye "
    $widget set x(2) "moon"
    string cat $foo $bar
} -result {goodbye moon}

test widget_vlink_unset_se_1 {
    # unset variable (scalar to array element link) (from parent)
} -body {
    unset foo bar
    set result ""
    lappend result [$widget eval info exists x(1)]
    lappend result [$widget eval info exists x(2)]
    lappend result [$widget eval info exists x]
} -result {0 0 1}

test widget_vlink_unset_se_2 {
    # unset variable (scalar to array element link) (from widget)
} -body {
    $widget vlink foo x(1)
    $widget vlink bar x(2)
    set foo hi 
    set bar there
    $widget eval unset x
    list [info exists foo] [info exists bar]
} -result {0 0}

test widget_vlink_write_ee {
    # write variable (array element to array element link)
} -body {
    $widget vlink x(1) x(1)
    set x(1) 5
    $widget get x(1)
} -result 5

test widget_vlink_read_ee {
    # read variable (array element to array element link)
} -body {
    $widget set x(1) 10
    set x(1)
} -result {10}

test widget_vlink_unset_ee1 {
    # unset variable (array element to array element link) (from parent)
} -body {
    unset x
    $widget eval {list [info exists x(1)] [info exists x]}
} -result {0 1}

test widget_vlink_unset_ee2 {
    # unset variable (array element to array element link) (from widget)
} -body {
    $widget vlink x(1) x(1)
    set x(1) 5
    $widget eval {unset x}
    list [info exists x(1)] [info exists x]
} -result {0 1}

test widget_vlink_write_es {
    # write variable (array element to scalar link)
} -body {
    $widget vlink x(1) y
    set x(1) 5
    set x(2) 6; # this element not linked
    $widget get y
} -result {5}

test widget_vlink_read_es {
    # read variable (array element to scalar link)
} -body {
    $widget set y 10
    array get x
} -result {1 10 2 6}

test widget_vlink_unset_es1 {
    # unset variable (array element to scalar link) (from parent)
} -body {
    unset x
    $widget eval info exists y
} -result {0}

test widget_vlink_unset_es2 {
    # unset variable (array element to scalar link) (from widget)
} -body {
    $widget vlink x(1) y
    set x(1) 5
    $widget eval {unset y}
    list [info exists x(1)] [info exists x]
} -result {0 1}

$widget destroy; # Clean up

# Check number of failed tests
set nFailed $::tcltest::numTests(Failed)

# Clean up and report on tests
cleanupTests

# If tests failed, return error
if {$nFailed > 0} {
    error "$nFailed tests failed"
}

# Final interactive mainLoop test
puts "press enter to update and install files"
mainLoop break

# Update and install
file copy -force {*}[glob -directory build *] [pwd]
tin bake doc/template/version.tin doc/template/version.tex $config
source install.tcl
