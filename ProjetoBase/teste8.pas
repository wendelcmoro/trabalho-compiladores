program proc1 (input, output);
var x, y: integer;
    procedure p;
        procedure k;
        var z,m,k:integer;
            begin
            z:=x;
            x:=x-1;
            if (z>1)
                then x:=x+1
                else y:=1;
            y:=y*z
        end
    begin
        write(5);
    end
begin
    read(x);
    write (x,y)
end.