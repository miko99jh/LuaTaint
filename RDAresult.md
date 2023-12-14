# The Reaching Definitions Analysis Results of the Listing1 Example

Applying the data flow constraint calculation to the Listing 1, the following results are obtained:

[entry]={}\
[x=io.read()]=[entry]\downarrow xcup{x=io.read( )}\
[while x>2]=[x=io.read()]cup[z=z+10]\
[y=x/2]=[while x>2]\downarrow ycup{y=x/2}\
[if y<6]=[y=x/2]\
[x=x+y]=[if y<6]\downarrow xcup{x=x+y}\
[z=x+2]=([x=x+y]cup[if y<6])downarrow zcup{z=x+2}\
[if z>3]=[z=x+2]\
[x=x/2]=[if z>3]downarrow xcup{x=x/2}\
[ z=z+10]=([x=x/2]cup[if z>3])downarrow zcup{z=x+10}\
[print(x)]=[while x>2]\
[exit]=[print(x)]\


One iteration of the above equation is solved as follows:

[entry]={ }\
[x=io.read()]={x=io.read()}\
[while x>2]={x=io.read()}\
[y=x/2]={x=io.read(),y=x/2}\
[if y<6]={x=io.read(),y=x/2}\
[x=x+y]={x=x+y,y=x/2}\
[z=x+2]={x=io.read(),x=x+y,y=x/2,z=x+2}\
[if z>3]={x=io.read(),x=x+y,y=x/2,z=x+2}\
[x=x/2]={x=x/2,y=x/2,z=x+2}\
[z=z+10]={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10}\
[print(x)]={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10}\
[exit]={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+10}\


The final results obtained by solving the above equations for several iterations up to the fixed-point are as follows:

[entry]={}\
[x=io.read()]={x=io.read()}\
[while x>2]={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10}\
[y=x/2]={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10}\
[if y<6]={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10}\
[x=x+y]={x=x+y,y=x/2,z=z+10}\
[z=x+2]={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+2}\
[if z>3]={x=io.read(),x=x+y,x=x/2,y=x/2,z=x+2}\
[x=x/2]={x=x/2,y=x/2,z=x+2}\
[z=z+10]={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10}\
[print(x)]={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10}\
[exit]={x=io.read(),x=x+y,x=x/2,y=x/2,z=z+10}\
