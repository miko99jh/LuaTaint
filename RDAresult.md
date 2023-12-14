# The Reaching Definitions Analysis Results of the Listing1 Example

Applying the data flow constraint calculation to the Listing 1, the following results are obtained:

$llbracket entryrrbracket={}$
$llbracket x=io.read()rrbracket=llbracket entryrrbracketdownarrow xcup{x=io.read( )}$
$llbracket while x>2rrbracket=llbracket x=io.read()rrbracketcupllbracket z=z+10rrbracket$
$llbracket y=x/2rrbracket=llbracket while x>2rrbracketdownarrow ycup{y=x/2}$
$llbracket if y<6rrbracket=llbracket y=x/2rrbracket$
$llbracket x=x+yrrbracket=llbracket if y<6rrbracketdownarrow xcup{x=x+y}$
$llbracket z=x+2rrbracket=(llbracket x=x+yrrbracketcupllbracket if y<6rrbracket)downarrow zcup{z=x+2}$
$llbracket if z>3rrbracket=llbracket z=x+2rrbracket$
$llbracket x=x/2rrbracket=llbracket if z>3rrbracketdownarrow xcup{x=x/2}$
$llbracket z=z+10rrbracket=(llbracket x=x/2rrbracketcupllbracket if z>3rrbracket)downarrow zcup{z=x+10}$
$llbracket print(x)rrbracket=llbracket while x>2rrbracket$
$llbracket exitrrbracket=llbracket print(x)rrbracket$


One iteration of the above equation is solved as follows:

$llbracket entryrrbracket={}$
$llbracket x=io.read()rrbracket={x=io.read()}$
$llbracket while x>2rrbracket={x=io.read()}$
$llbracket y=x/2rrbracket={x=io.read(),y=x/2}$
$llbracket if y<6rrbracket={x=io.read(),y=x/2}$
$llbracket x=x+yrrbracket={x=x+y,y=x/2}$
$llbracket z=x+2rrbracket={x=io.read(),x=x+y,y=x/2,z=x+2}$
$llbracket if z>3rrbracket={x=io.read(),x=x+y,y=x/2,z=x+2}$
$llbracket x=x/2rrbracket={x=x/2,y=x/2,z=x+2}$
$llbracket z=z+10rrbracket={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10}$
$llbracket print(x)rrbracket={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10}$
$llbracket exitrrbracket={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10}$


The final results obtained by solving the above equations for several iterations up to the fixed-point are as follows:

$llbracket entryrrbracket={}$
$llbracket x=io.read()rrbracket={x=io.read()}$
$llbracket while x>2rrbracket={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10}$
$llbracket y=x/2rrbracket={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10}$
$llbracket if y<6rrbracket={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10}$
$llbracket x=x+yrrbracket={x=x+y,y=x/2,z=z+10}$
$llbracket z=x+2rrbracket={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+2}$
$llbracket if z>3rrbracket={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+2}$
$llbracket x=x/2rrbracket={x=x/2,y=x/2,z=x+2}$
$llbracket z=z+10rrbracket={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10}$
$llbracket print(x)rrbracket={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10}$
$llbracket exitrrbracket={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10}$
