# The Reaching Definitions Analysis Results of the Listing1 Example

Applying the data flow constraint calculation to the Listing 1, the following results are obtained:

![image](https://github.com/miko99jh/LuaTaint/blob/main/img/Pic61.png)
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
