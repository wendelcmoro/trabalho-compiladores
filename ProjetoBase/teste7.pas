program cmdIf (input, output);
var i, j: integer;
begin
    read(j);
    i:=0;
    if ((i = 2) and ((i = 1) or (j = 0)))
    then
        if (i div 2 * 2 = i)
        then
            write(i,2)
        else
            write(i,3);

    write(i,6);
    i:=i+1;
    i:=i+4;
end.