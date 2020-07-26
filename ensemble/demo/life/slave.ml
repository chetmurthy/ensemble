(**************************************************************)
(*
 *  Ensemble, (Version 1.00)
 *  Copyright 2000 Cornell University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
(**************************************************************)
open Ensemble
open Appl
open Appl_intf open Old
open Transport
open Proto
open Util
open Msgs
open Rules
open Debug
open View
(**************************************************************)
let name = Trace.file "SLAVE"
(**************************************************************)

(* This function returns the interface record that defines
 * the callbacks for the application. 
 *)

let life master_endpt rate = 
   (* my current view *)
  let view = ref []
   (* my co-ordinates *)
  and  myXY  = ref (-1,-1)
   (* have I gotten the co-ordinates yet? *)
  and gotXY = ref false 
   (* number of generations: -1 if not initialized *)
  and gens = ref (-1)
   (* neighbour list *)
  and neighbours = ref []
   (* have I gotten my neighbours yet? *)
  and gotNeighbours = ref false
   (* my live/dead state over time *)
  and cellValue = ref [||]
   (* dead neighbour counts over time *)
  and deadCount = ref [||]
   (* live neighbour counts over time *)
  and liveCount = ref [||]
  and outmsgs = ref [] 
  and inmsgs = ref [] in
  let rec masterRank () = index master_endpt !view 
  and queueOutMsg m = outmsgs := m :: !outmsgs
  and sendMsgs () =   let out = !outmsgs in
                         outmsgs := [];
                         Array.of_list out
  and queueInMsgs m = inmsgs := m :: !inmsgs
  and readyToHandleValues () = (!gens <> -1) && !gotXY && !gotNeighbours
  and handleBoundaries () = if (!gotNeighbours && (!gens > -1)) then
                              let borders = 8 - List.length(!neighbours) in
                                for g = 0 to !gens do
                                  !deadCount.(g) <- !deadCount.(g)+borders
                                done
  and updateCellValue g v = 
                     !cellValue.(g)<- v;
                     queueOutMsg (Send ([|masterRank ()|],MyValue (g,!myXY,v)));
                     if (g < !gens) then
                       (queueOutMsg (Send ((Array.of_list !neighbours), NeighbourValue (g,v)));
                        recalculateValue (g+1);
                        ())
                     else
                       ()
  and handleNeighbourValue g v =
                   if !cellValue.(g+1) = Bottom then
                    ((if (v=Live) then
                        !liveCount.(g)<- !liveCount.(g)+1
                      else
                        !deadCount.(g)<- !deadCount.(g)+1);
                      recalculateValue (g+1);
                      ())
                   else
                     ()
  and recalculateValue g =
                  if !cellValue.(g) = Bottom then
                     let newValue = nextCell !cellValue.(g-1) 
                                             !liveCount.(g-1)
                                             !deadCount.(g-1)
                     in
                        if (newValue = Bottom) then
                          ()
                        else
                          (updateCellValue g newValue)
                  else
                    ()
  and mycoord () = "("^(string_of_int (fst !myXY))^","^(string_of_int (snd !myXY)) ^ ")"
  and processInQueue () =
    let msgs = !inmsgs in
      inmsgs := [];
      (* Notice that we take care to process the latest message first *)
      (* If we didn't, then the old messages would be put back on the *)
      (* queue, and not taken care of until the NEXT message!         *)
      List.iter processMsg msgs
  and processMsg m =
    match m
    with NumberOfGenerations g -> gens := g;
                                  cellValue := Array.create (g+1) Bottom;
                                  deadCount := Array.create (g+1) 0;
                                  liveCount := Array.create (g+1) 0;
                                  handleBoundaries ();
                                  ()
     |   YourCoordinates (x,y) -> 
                 if (!gotXY) then
                   (print_string "Error!!!!  Got Coordinates twice";
                    flush stdout)
                 else
                    begin
                     myXY := (x,y);
                     gotXY := true
                    end;
                  ()
     |   YourNeighbours n -> if (!gotNeighbours) then
                              (print_string "Error!!! Got Neighbours twice.\n";
                               flush stdout;
                               ())
                             else
                               (neighbours := n;
                                gotNeighbours := true;
                                handleBoundaries ();
                                ())
     |   InitValue v -> if readyToHandleValues () then
                          updateCellValue 0 v
                        else
                          queueInMsgs (InitValue v)
     |   NeighbourValue (g,v) -> if readyToHandleValues () then
                                    handleNeighbourValue g v
                                 else
                                    queueInMsgs (NeighbourValue (g,v))
     |    _ -> ()           
  and queueAndSend _ m = queueInMsgs m;
                         processInQueue ();
                         sendMsgs ()
  and queueAndProcess _ m = queueInMsgs m;
                            processInQueue ();
                            ()
  in
  let recv_cast x m= queueAndSend x m
  and recv_send x m= queueAndSend x m
  and block () = [||]
  and heartbeat _ =
    processInQueue ();
    sendMsgs ()
  and block_recv_cast = queueAndProcess
  and block_recv_send = queueAndProcess
  and block_view (ls,vs) =
    if ls.rank = 0 then
      List.map (fun rank -> (rank,())) (Array.to_list (Util.sequence ls.nmembers))
    else []
  and block_install_view vs _ = ()
  and unblock_view (ls,vs) () =
    view := Arrayf.to_list vs.view ;
    [||]
  and exit () =
    eprintf "(lifeslave:got exit)\n" ;
    exit 0
  in Elink.get_appl_old_full name {
    recv_cast           = recv_cast ;
    recv_send           = recv_send ;
    
    heartbeat           = heartbeat ;
    heartbeat_rate      = rate ;
    block               = block ;
    block_recv_cast     = block_recv_cast ;
    block_recv_send     = block_recv_send ;
    block_view          = block_view ;
    block_install_view  = block_install_view ;
    unblock_view        = unblock_view ;
    exit                = exit
  } 

(**************************************************************)

let initSlave master_endpt rate = 
  life master_endpt rate
