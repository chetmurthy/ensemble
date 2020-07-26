(**************************************************************)
(*
 *  Ensemble, 2_00
 *  Copyright 2004 Cornell University, Hebrew University
 *           IBM Israel Science and Technology
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
(* CRYPTOKIT_INT *)
(* Author: Ohad Rodeh, 3/2004 *)
(**************************************************************)
(* Pseudo-random number generator *)
  
(**************************************************************)
let common_err = "This is the fake cryptographic library. You need to compile and link with the real library."

module Prng = struct

  let init seed = failwith common_err
      
  let rand len = failwith common_err
end
  
(**************************************************************)

module Cipher = struct 

  let encrypt key flag buf = failwith common_err

end

(**************************************************************)

module DH = struct

  type key = ()

  type pub_key = string

  type param = ()

  let init _ = failwith common_err
      
  let generate_parameters _ = failwith common_err

  let param_of_string _ =  failwith common_err

  let string_of_param _ =  failwith common_err

  let generate_key param = failwith common_err
      
  let get_p param = failwith common_err

  let get_g param = failwith common_err

  let get_pub key = failwith common_err

  let key_of_string buf = failwith common_err

  let string_of_key key = failwith common_err

  let string_of_pub_key pub_key = failwith common_err

  let pub_key_of_string pub_key = failwith common_err

  let compute_key key pub_key = failwith common_err

end
  
(**************************************************************)
