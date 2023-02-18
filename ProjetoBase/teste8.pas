program proc1 (input, output);
var x, y: integer;
    procedure p;
        procedure q;
            procedure r;
            var k,l,m : integer;
            begin
                r
            end

            procedure s;
            var z,m,y:integer;
            begin
                z:=x;
                x:=x-1;
                if (z>1)
                    then p
                    else y:=1;
                y:=y*z
            end
        begin
            r;
            s;
            write(10);
        end
    begin
        q
        write(5);
    end

    procedure t;
        procedure u;
        var z,m,l:integer;
        begin
            z:=x;
            x:=x-1;
            if (z>1)
                then u
                else y:=1;
            y:=y*z
        end

        procedure q;
        begin
            u
        end

    begin
        u;
        q;
        write(5);
    end
begin
    read(x);
    p;
    t;
    write (x,y)
end.