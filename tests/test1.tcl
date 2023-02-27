package require wob
namespace import wob::*

set widget [widget new]
set filename [$widget eval tk_getOpenFile]
$widget destroy
puts $filename
