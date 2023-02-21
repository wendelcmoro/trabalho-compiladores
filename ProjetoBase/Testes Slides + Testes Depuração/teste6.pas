program cmdIf (input, output);
var i, j: integer;
k : integer;
begin
    read(j);
    i:=0;
    while ((i < j) and (k < 0)) do
    begin
        if (i div 2 * 2 = i)
            then
                write(i,0)
            else
                write(i,1);
                
        i:=i+1;
        
        if (i div 2 * 2 = i)
            then
                write(i,2)
            else
                write(i,3);

        i:=i+4;
    end;
end.