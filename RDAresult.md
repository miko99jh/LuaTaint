# The Reaching Definitions Analysis Results of the Listing1 Example

Applying the data flow constraint calculation to the Listing 1, the following results are obtained:

$⟦entry⟧={\rbrace$ \
$⟦x=io.read()⟧=⟦entry⟧\downarrow x\cup{x=io.read( )\rbrace$ \
$⟦while\ x>2⟧=⟦x=io.read()⟧\cup⟦z=z+10⟧$ \
$⟦y=x/2⟧=⟦while\ x>2⟧\downarrow y\cup{y=x/2\rbrace$ \
$⟦if\ y<6⟧=⟦y=x/2⟧$ \
$⟦x=x+y⟧=⟦if\ y<6⟧\downarrow x\cup{x=x+y\rbrace$ \
$⟦z=x+2⟧=(⟦x=x+y⟧\cup⟦if\ y<6⟧)\downarrow z\cup{z=x+2\rbrace$ \
$⟦if\ z>3⟧=⟦z=x+2⟧$ \
$⟦x=x/2⟧=⟦if\ z>3⟧\downarrow x\cup{x=x/2\rbrace$ \
$⟦z=z+10⟧=(⟦x=x/2⟧\cup⟦if\ z>3⟧)\downarrow z\cup{z=x+10\rbrace$ \
$⟦print(x)⟧=⟦while\ x>2⟧$ \
$⟦exit⟧=⟦print(x)⟧$ \
\
\
One iteration of the above equation is solved as follows:

$⟦entry⟧={\rbrace$ \
$⟦x=io.read()⟧={x=io.read()\rbrace$ \
$⟦while\ x>2⟧={x=io.read()\rbrace$ \
$⟦y=x/2⟧={x=io.read(),y=x/2\rbrace$ \
$⟦if\ y<6⟧={x=io.read(),y=x/2\rbrace$ \
$⟦x=x+y⟧={x=x+y,y=x/2\rbrace$ \
$⟦z=x+2⟧={x=io.read(),x=x+y,y=x/2,z=x+2\rbrace$ \
$⟦if\ z>3⟧={x=io.read(),x=x+y,y=x/2,z=x+2\rbrace$ \
$⟦x=x/2⟧={x=x/2,y=x/2,z=x+2\rbrace$ \
$⟦z=z+10⟧={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10\rbrace$ \
$⟦print(x)⟧={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10\rbrace$ \
$⟦exit⟧={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10\rbrace$ \
\
\
The final results obtained by solving the above equations for several iterations up to the fixed-point are as follows:

$⟦entry⟧={\rbrace$ \
$⟦x=io.read()⟧={x=io.read()\rbrace$ \
$⟦while\ x>2⟧={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\rbrace$ \
$⟦y=x/2⟧={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\rbrace$ \
$⟦if\ y<6⟧={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\rbrace$ \
$⟦x=x+y⟧={x=x+y,y=x/2,z=z+10\rbrace$ \
$⟦z=x+2⟧={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+2\rbrace$ \
$⟦if\ z>3⟧={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+2\rbrace$ \
$⟦x=x/2⟧={x=x/2,y=x/2,z=x+2\rbrace$ \
$⟦z=z+10⟧={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\rbrace$ \
$⟦print(x)⟧={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\rbrace$ \
$⟦exit⟧={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\rbrace$
