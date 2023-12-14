# The Reaching Definitions Analysis Results of the Listing1 Example

Applying the data flow constraint calculation to the Listing 1, the following results are obtained:

$⟦entry⟧=\lbrace \rbrace$ \
$⟦x=io.read()⟧=⟦entry⟧\downarrow x\cup\lbrace x=io.read( )\rbrace$ \
$⟦while\ x>2⟧=⟦x=io.read()⟧\cup⟦z=z+10⟧$ \
$⟦y=x/2⟧=⟦while\ x>2⟧\downarrow y\cup\lbrace y=x/2\rbrace$ \
$⟦if\ y<6⟧=⟦y=x/2⟧$ \
$⟦x=x+y⟧=⟦if\ y<6⟧\downarrow x\cup\lbrace x=x+y\rbrace$ \
$⟦z=x+2⟧=(⟦x=x+y⟧\cup⟦if\ y<6⟧)\downarrow z\cup\lbrace z=x+2\rbrace$ \
$⟦if\ z>3⟧=⟦z=x+2⟧$ \
$⟦x=x/2⟧=⟦if\ z>3⟧\downarrow x\cup\lbrace x=x/2\rbrace$ \
$⟦z=z+10⟧=(⟦x=x/2⟧\cup⟦if\ z>3⟧)\downarrow z\cup\lbrace z=x+10\rbrace$ \
$⟦print(x)⟧=⟦while\ x>2⟧$ \
$⟦exit⟧=⟦print(x)⟧$ \
\
\
One iteration of the above equation is solved as follows:

$⟦entry⟧=\lbrace \rbrace$ \
$⟦x=io.read()⟧=\lbrace x=io.read()\rbrace$ \
$⟦while\ x>2⟧=\lbrace x=io.read()\rbrace$ \
$⟦y=x/2⟧=\lbrace x=io.read(),y=x/2\rbrace$ \
$⟦if\ y<6⟧=\lbrace x=io.read(),y=x/2\rbrace$ \
$⟦x=x+y⟧=\lbrace x=x+y,y=x/2\rbrace$ \
$⟦z=x+2⟧=\lbrace x=io.read(),x=x+y,y=x/2,z=x+2\rbrace$ \
$⟦if\ z>3⟧=\lbrace x=io.read(),x=x+y,y=x/2,z=x+2\rbrace$ \
$⟦x=x/2⟧=\lbrace x=x/2,y=x/2,z=x+2\rbrace$ \
$⟦z=z+10⟧=\lbrace x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10\rbrace$ \
$⟦print(x)⟧=\lbrace x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10\rbrace$ \
$⟦exit⟧=\lbrace x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10\rbrace$ \
\
\
The final results obtained by solving the above equations for several iterations up to the fixed-point are as follows:

$⟦entry⟧=\lbrace \rbrace$ \
$⟦x=io.read()⟧=\lbrace x=io.read()\rbrace$ \
$⟦while\ x>2⟧=\lbrace x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\rbrace$ \
$⟦y=x/2⟧=\lbrace x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\rbrace$ \
$⟦if\ y<6⟧=\lbrace x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\rbrace$ \
$⟦x=x+y⟧=\lbrace x=x+y,y=x/2,z=z+10\rbrace$ \
$⟦z=x+2⟧=\lbrace x=io.read(),x=x+y,x=x/2,y=x/2,z=x+2\rbrace$ \
$⟦if\ z>3⟧=\lbrace x=io.read(),x=x+y,x=x/2,y=x/2,z=x+2\rbrace$ \
$⟦x=x/2⟧=\lbrace x=x/2,y=x/2,z=x+2\rbrace$ \
$⟦z=z+10⟧=\lbrace x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\rbrace$ \
$⟦print(x)⟧=\lbrace x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\rbrace$ \
$⟦exit⟧=\lbrace x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10\rbrace$
