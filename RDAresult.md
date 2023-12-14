# The Reaching Definitions Analysis Results of the Listing1 Example

Applying the data flow constraint calculation to the Listing 1, the following results are obtained:

$⟦entry⟧={}$ \
$⟦x=io.read()\rrbracket=⟦entry\rrbracket\downarrow x\cup\{x=io.read( )\}$ \
$⟦while\ x>2\rrbracket=⟦x=io.read()\rrbracket\cup⟦z=z+10\rrbracket$ \
$⟦y=x/2\rrbracket=⟦while\ x>2\rrbracket\downarrow y\cup\{y=x/2\}$ \
$⟦if\ y<6\rrbracket=⟦y=x/2\rrbracket$ \
$⟦x=x+y\rrbracket=⟦if\ y<6\rrbracket\downarrow x\cup\{x=x+y\}$ \
$⟦z=x+2\rrbracket=(⟦x=x+y\rrbracket\cup⟦if\ y<6\rrbracket)\downarrow z\cup\{z=x+2\}$ \
$⟦if\ z>3\rrbracket=⟦z=x+2\rrbracket$ \
$⟦x=x/2\rrbracket=⟦if\ z>3\rrbracket\downarrow x\cup\{x=x/2\}$ \
$⟦z=z+10\rrbracket=(⟦x=x/2\rrbracket\cup⟦if\ z>3\rrbracket)\downarrow z\cup\{z=x+10\}$ \
$⟦print(x)\rrbracket=⟦while\ x>2\rrbracket$ \
$⟦exit\rrbracket=⟦print(x)\rrbracket$ \
\
\
One iteration of the above equation is solved as follows:

$⟦entry\rrbracket=\{\}$ \
$⟦x=io.read()\rrbracket=\{x=io.read()\}$ \
$⟦while\ x>2\rrbracket=\{x=io.read()\}$ \
$⟦y=x/2\rrbracket=\{x=io.read(),y=x/2\}$ \
$⟦if\ y<6\rrbracket=\{x=io.read(),y=x/2\}$ \
$⟦x=x+y\rrbracket=\{x=x+y,y=x/2\}$ \
$⟦z=x+2\rrbracket=\{x=io.read(),x=x+y,y=x/2,z=x+2\}$ \
$⟦if\ z>3\rrbracket=\{x=io.read(),x=x+y,y=x/2,z=x+2\}$ \
$⟦x=x/2\rrbracket=\{x=x/2,y=x/2,z=x+2\}$ \
$⟦z=z+10\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10\}$ \
$⟦print(x)\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10\}$ \
$⟦exit\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10\}$ \
\
\
The final results obtained by solving the above equations for several iterations up to the fixed-point are as follows:

$⟦entry\rrbracket=\{\}$ \
$⟦x=io.read()\rrbracket=\{x=io.read()\}$ \
$⟦while\ x>2\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\}$ \
$⟦y=x/2\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\}$ \
$⟦if\ y<6\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\}$ \
$⟦x=x+y\rrbracket=\{x=x+y,y=x/2,z=z+10\}$ \
$⟦z=x+2\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=x+2\}$ \
$⟦if\ z>3\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=x+2\}$ \
$⟦x=x/2\rrbracket=\{x=x/2,y=x/2,z=x+2\}$ \
$⟦z=z+10\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\}$ \
$⟦print(x)\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\}$ \
$⟦exit\rrbracket=\{x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\}$ \
