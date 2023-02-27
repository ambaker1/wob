package require wob
namespace import wob::*

set widget [widget new]
$widget set text "hello world"
$widget eval {
	clipboard clear
	clipboard append $text
}
mainLoop
# now the text "hello world" can be pasted into another application.
