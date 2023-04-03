# wob.tcl
 Widget Objects in Tcl
 
 Create widgets with their own Tcl object and their own interpreter. 
 
## Installation
Wob is a Tin package. Tin makes installing Tcl packages easy, and is available [here](https://github.com/ambaker1/Tin).
After installing Tin, simply include the following in your script to install wob:
```tcl
package require tin
tin install wob
```
This will install wob and all dependent Tin packages.
Once wob is installed, use the following code to load the package and import the commands.
```tcl
package require wob
namespace import wob::*
```
Alternatively, the Tin package can also be used to easily import the commands.
```tcl
package require tin
tin import wob
```
