program comandoWhile(input, output);
var n, k: integer; 
    f1, f2, f3:integer;
begin             
    read(n);     
    f1:=0; f2:=1; k:=1;
    while (k <= n) do  
    begin              
        f3:=f2+f1;      
        f1:=f2;         
        f2:=f3;        
        k:=k+1;
        while (k <= n) do  
        begin              
            f3:=f2+f1;      
            f1:=f2;         
            f2:=f3;        
            k:=k+1;
            while (k <= n) do  
            begin              
                f3:=f2+f1;      
                f1:=f2;         
                f2:=f3;        
                k:=k+1;
            end;
            write(0);
        end;
        write(1);
    end;                 
    write(n,k);

    read(k);
    while (k <= n) do  
    begin              
        f3:=f2+f1;      
        f1:=f2;         
        f2:=f3;        
        k:=k+1;
    end;
    write(3);
end.