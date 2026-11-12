with Ada.Text_IO;

procedure Hello is
   Boom : exception;

   procedure Fail is
   begin
      raise Boom;
   end Fail;
begin
   Ada.Text_IO.Put_Line ("Hello from Ada on wasm32");
   begin
      Fail;
   exception
      when Boom =>
         Ada.Text_IO.Put_Line ("caught Boom");
   end;
end Hello;
