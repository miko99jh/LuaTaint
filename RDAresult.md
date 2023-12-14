# The Reaching Definitions Analysis Results of the Listing1 Example

Applying the data flow constraint calculation to the Listing 1, the following results are obtained:

$\llbracket entry\rrbracket={}$ \
$\llbracket x=io.read()\rrbracket=\llbracket entry\rrbracket\downarrow x\cup\{x=io.read( )\}$ \
$\llbracket while\ x>2\rrbracket=\llbracket x=io.read()\rrbracket\cup\llbracket z=z+10\rrbracket$ \
$\llbracket y=x/2\rrbracket=\llbracket while\ x>2\rrbracket\downarrow y\cup\{y=x/2\}$ \
$\llbracket if\ y<6\rrbracket=\llbracket y=x/2\rrbracket$ \
$\llbracket x=x+y\rrbracket=\llbracket if\ y<6\rrbracket\downarrow x\cup\{x=x+y\}$ \
$\llbracket z=x+2\rrbracket=(\llbracket x=x+y\rrbracket\cup\llbracket if\ y<6\rrbracket)\downarrow z\cup\{z=x+2\}$ \
$\llbracket if\ z>3\rrbracket=\llbracket z=x+2\rrbracket$ \
$\llbracket x=x/2\rrbracket=\llbracket if\ z>3\rrbracket\downarrow x\cup\{x=x/2\}$ \
$\llbracket z=z+10\rrbracket=(\llbracket x=x/2\rrbracket\cup\llbracket if\ z>3\rrbracket)\downarrow z\cup\{z=x+10\}$ \
$\llbracket print(x)\rrbracket=\llbracket while\ x>2\rrbracket$ \
$\llbracket exit\rrbracket=\llbracket print(x)\rrbracket$ \
\
\
One iteration of the above equation is solved as follows:

$\llbracket entry\rrbracket=\{\}$ \
$\llbracket x=io.read()\rrbracket=\{x=io.read()\}$ \
$\llbracket while\ x>2\rrbracket=\{x=io.read()\}$ \
$\llbracket y=x/2\rrbracket=\{x=io.read(),y=x/2\}$ \
$\llbracket if\ y<6\rrbracket=\{x=io.read(),y=x/2\}$ \
$\llbracket x=x+y\rrbracket=\{x=x+y,y=x/2\}$ \
$\llbracket z=x+2\rrbracket=\{x=io.read(),x=x+y,y=x/2,z=x+2\}$ \
$\llbracket if\ z>3\rrbracket=\{x=io.read(),x=x+y,y=x/2,z=x+2\}$ \
$\llbracket x=x/2\rrbracket=\{x=x/2,y=x/2,z=x+2\}$ \
$\llbracket z=z+10\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10\}$ \
$\llbracket print(x)\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10\}$ \
$\llbracket exit\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10\}$ \
\
\
The final results obtained by solving the above equations for several iterations up to the fixed-point are as follows:

$\llbracket entry\rrbracket=\{\}$ \
$\llbracket x=io.read()\rrbracket=\{x=io.read()\}$ \
$\llbracket while\ x>2\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\}$ \
$\llbracket y=x/2\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\}$ \
$\llbracket if\ y<6\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\}$ \
$\llbracket x=x+y\rrbracket=\{x=x+y,y=x/2,z=z+10\}$ \
$\llbracket z=x+2\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=x+2\}$ \
$\llbracket if\ z>3\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=x+2\}$ \
$\llbracket x=x/2\rrbracket=\{x=x/2,y=x/2,z=x+2\}$ \
$\llbracket z=z+10\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\}$ \
$\llbracket print(x)\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\}$ \
$\llbracket exit\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\}$ \
