# wob: Tcl Widget Objects

Create widgets with their own Tcl object and their own interpreter.

Full documentation [here](doc/wob.pdf).
 
## Installation
This package is a Tin package. 
Tin makes installing Tcl packages easy, and is available [here](https://github.com/ambaker1/Tin).

After installing Tin, simply run the following Tcl code to install the most recent version of "wob":
```tcl
package require tin 0.4
tin add -auto wob https://github.com/ambaker1/wob install.tcl 0.1.3-
tin fetch wob
tin install wob
```
