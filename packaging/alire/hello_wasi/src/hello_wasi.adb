with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;

procedure Hello_Wasi is
   use Ada.Text_IO;

   File : File_Type;
begin
   Put_Line ("Hello from Ada on WASI");

   for I in 1 .. Ada.Command_Line.Argument_Count loop
      Put_Line ("arg" & I'Image & ": " & Ada.Command_Line.Argument (I));
   end loop;

   begin
      raise Constraint_Error with "and exceptions work";
   exception
      when E : Constraint_Error =>
         Put_Line ("caught: " & Ada.Exceptions.Exception_Message (E));
   end;

   --  The current directory is a preopened host directory
   Create (File, Out_File, "hello_wasi.txt");
   Put_Line (File, "written from WASI");
   Close (File);
   Open (File, In_File, "hello_wasi.txt");
   Put_Line ("file: " & Get_Line (File));
   Close (File);

   Ada.Command_Line.Set_Exit_Status (3);
end Hello_Wasi;
