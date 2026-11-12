#!/bin/bash

set -eu

default_target="$1"
llvm_version="${2:-}"

cat << EOF > obj/tmp-options-target.ads
package Options.Target is
   Default_Target_Triple : constant String := "$default_target";
   LLVM_Version          : constant String := "$llvm_version";
end Options.Target;
EOF

./move-if-change obj/tmp-options-target.ads obj/options-target.ads
