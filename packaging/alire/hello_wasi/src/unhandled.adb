--  An unhandled exception must print GNAT's "raised ..." message and exit
--  with status 1, as natively.

procedure Unhandled is
begin
   raise Program_Error with "deliberately unhandled";
end Unhandled;
