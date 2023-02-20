program proc2 (input, output);
var x, y: integer;
    procedure p(t:integer);
    var z:integer;
        begin
            if (t>1)
                then p(t-1);
                else y:=1;
            z:= y;
            y:=z*t;
    end
    
    procedure k(t:integer);
    var z,l:integer;
        begin
            if (t>1)
                then p(t-1);
                else y:=1;
            z:= y;
            y:=z*t;
    end
begin
    read(x);
    p(x);
    k(x);
    write (x,y)
end.