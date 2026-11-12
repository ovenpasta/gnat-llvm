with Interfaces;

package Calc is

   function Square_Root
     (Value : Interfaces.IEEE_Float_64) return Interfaces.IEEE_Float_64
     with Export => True, Convention => C, Link_Name => "Square_Root";
   --  Raises Constraint_Error internally for negative values and returns
   --  -1.0, to exercise exception handling under the EH runtimes.

end Calc;
