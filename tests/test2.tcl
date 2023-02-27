package require wob
namespace import wob::*

set widget [widget new]
$widget eval {
label .label -text "Choose analysis type:"
tk_optionMenu .options AnalysisType "" Pushover Dynamic
pack .label -side top -fill x
pack .options -side bottom -fill x
vwait AnalysisType
}
puts [$widget get AnalysisType]
$widget destroy
