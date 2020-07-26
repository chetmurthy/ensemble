type cell = Dead
          | Live
          | Bottom

let compareCells = fun x y -> if x=y then x else Bottom

let cell2int = function Bottom -> 0
                |  Dead -> 1
                |  Live -> 2

let orig =[| [|Dead;Dead;Dead;Live;Dead;Dead;Dead;Dead;Dead|];
             [|Dead;Dead;Live;Live;Dead;Dead;Dead;Dead;Dead|] |]

let nextMatrix = [| Array.create_matrix 9 9 Bottom; Array.create_matrix 9 9 Bottom ;
                    Array.create_matrix 9 9 Bottom |]

let initNextMatrix = fun () ->
  for numlive = 0 to 8 do
    nextMatrix.(cell2int Bottom).(numlive).(8-numlive)<- compareCells (orig.(0).(numlive))
                                                      (orig.(1).(numlive))
  done;
  for numlive = 0 to 8 do
    nextMatrix.(cell2int Dead).(numlive).(8-numlive)<- orig.(0).(numlive);
    nextMatrix.(cell2int Live).(numlive).(8-numlive)<- orig.(1).(numlive)
  done;
  for liveness = 0 to 2 do
    for unknown = 1 to 8 do
      let ymax = 8-unknown in
        for x = 0 to ymax do
          let y = 8-x-unknown in
            nextMatrix.(liveness).(x).(y)<- compareCells (nextMatrix.(liveness).(x).(y+1))
                                           (nextMatrix.(liveness).(x+1).(y))
        done
    done
  done

let nextCell =
  initNextMatrix ();
  fun current numlive numdead ->
    nextMatrix.(cell2int current).(numlive).(numdead)
