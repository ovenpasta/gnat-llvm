with Ada.Numerics.Generic_Elementary_Functions;

package body Calc is

   use type Interfaces.IEEE_Float_64;

   package Elementary_Functions is
     new Ada.Numerics.Generic_Elementary_Functions (Interfaces.IEEE_Float_64);

   -----------------
   -- Square_Root --
   -----------------

   function Square_Root
     (Value : Interfaces.IEEE_Float_64) return Interfaces.IEEE_Float_64 is
   begin
      if Value < 0.0 then
         raise Constraint_Error with "negative";
      end if;

      return Elementary_Functions.Sqrt (Value);

   exception
      when Constraint_Error =>
         return -1.0;
   end Square_Root;

end Calc;
