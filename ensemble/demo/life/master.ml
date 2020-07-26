open Ensemble
open Appl
open Appl_intf open Old
open Util
open Transport
open Proto
open Msgs
open Slave
open Rules
open Debug
open View
(**************************************************************)
let name = Trace.file "MASTER"
(**************************************************************)

type board = int * int -> bool

(* The status of the computation *)
type status = 
              (* nothing has started yet *)
            Idle  
              (* creating endpoints with arguments xdim, ydim, board 
                 and number of generations to compute *)
            | Starting of  int*int*board*int 
              (* computation in progress *)
            | Computing of int*int*board*int
              (* computation finished *)
            | Stopping

(* The actual status *)
let state = ref Idle

(* callbacks *)
let cellValueFunc = ref (fun g l c -> ())

let viewFunc = ref (fun c -> ())

let exitFunc = ref (fun () -> ())

let setCellValueFunc f = cellValueFunc := f

let setViewFunc f = viewFunc := f

let setExitFunc f = exitFunc := f

(**************************************************************)

  (* startMaster merely has to set the state correctly.  This will *)
  (* be acted upon at the next heartbeat. *)

let startMaster xdim ydim initboard generations =
  state := Starting (xdim,ydim,initboard,generations)

(* This function returns the interface record that defines
 * the callbacks for the application. 
 *)

let life my_endpt makeSlave rate =
     (* our current view *)
  let view = ref []
     (* the matrix of slave endpts *)
  and slaves = ref [||]
     (* number of slaves started *)
  and numstarted = ref 0
     (* number of cell values computed *)
  and numValuesComputed = ref 0
     (* the queue of outgoing messages *)
  and outmsgs = ref [] in
      (* function to queue messages to be sent *)
    let queueOutMsg m = outmsgs := m :: !outmsgs
      (* function to return list of messages that need to be sent *)
    and sendMsgs () = let out = !outmsgs in 
                            outmsgs := [];
                            Array.of_list out
      (* initialize matrix of slave endpts *)
    and assignSlaves l = 
        match !state with
           Computing (xdim,ydim,_,_) ->
            slaves := Array.create xdim [||];
            let slavelist= Array.of_list (except my_endpt l) in
              for x = 0 to xdim-1 do
                !slaves.(x)<- Array.sub slavelist (x*ydim) ydim
              done
          | _ -> ()
    and coords2rank (x,y) = index (!slaves.(x).(y)) !view
    and endptlist2ranklist el = List.map (fun x -> index x !view) el
    and neighbours x y = 
      let xdim,ydim = match !state with 
      | Computing(xdim,ydim,_,_) -> xdim,ydim
      | _ -> failwith sanity
      in
      let rec fromto a b = if (a>b) then
                             []
                           else
                             a::(fromto (a+1) b)
      and makePairs = function [] -> (fun b -> [])
                       | (h::t) -> (fun b -> (List.map (fun x -> (h,x)) b) @ makePairs t b)
      in
        except (x,y)
               (makePairs (fromto (max 0 (x-1)) (min (x+1) (xdim-1)))
                          (fromto (max 0 (y-1)) (min (y+1) (ydim-1))))
    and receiveMsg m =
       let xdim,ydim,gens = match !state with 
       | Computing(xdim,ydim,_,gens) -> xdim,ydim,gens
       | _ -> failwith sanity
       in
       (match m with
         MyValue (g,(x,y),v) -> 
             incr numValuesComputed;
             !cellValueFunc g (x,y) v;
             if (!numValuesComputed == xdim*ydim*(1+gens)) then
               begin
                (* We've finished *)
                !exitFunc ()
               end
             else
               ()
         | NumberOfGenerations _ -> print_string("NG");flush stdout
         | YourCoordinates _ -> print_string("YC");flush stdout
         | YourNeighbours _ -> print_string("YN");flush stdout
         | InitValue _  -> print_string("IV");flush stdout
         | NeighbourValue _ -> print_string("NV");flush stdout
         | Test _ ->  print_string("test ");flush stdout
        );
       [||]
  in
  let recv_cast _ m = [||]
  and recv_send _ m = receiveMsg m
  and block () = [||]
  and heartbeat _ =
    begin
      begin
        match !state with
          Starting (xdim,_,_,_) ->
            if !numstarted == 0 then
              begin
                makeSlave ();
                incr numstarted
              end
            else
              ()
          | _ -> ()
      end;
      sendMsgs ()
    end
  and block_recv_cast _ m = ()
  and block_recv_send _ m = unit (receiveMsg m)
  and block_view (ls,vs) = 
    if ls.rank = 0 then
      List.map (fun rank -> (rank,())) (Array.to_list (Util.sequence ls.nmembers))
    else []
  and block_install_view vs _ = ()
  and unblock_view (ls,vs) () =
    let view' = Arrayf.to_list vs.view in
    !viewFunc (List.length view');
    view := view';
    match !state with
      Computing _ -> 
        begin
          [||]
        end
     |Idle ->
        begin
          if (List.length view' == 1) then
            [||]
          else
            begin
              eprintf "Protocol Error!\n";
              flush stdout;
              exit 1;
              [||]
            end
        end
     |Stopping -> [||]
     |Starting (xdim, ydim, board, gens) ->
          if (List.length view' == xdim*ydim+1) then
            (* Everyone's here! *)
            begin
              state := Computing(xdim,ydim,board,gens);
              assignSlaves view';
              for x = 0 to (xdim-1) do
                for y = 0 to ydim-1 do
                  queueOutMsg (Send ([|coords2rank (x,y)|],YourCoordinates (x,y)))
                done
              done;
              queueOutMsg (Cast (NumberOfGenerations gens));
              for x = 0 to xdim-1 do
               for y = 0 to ydim-1 do
                 queueOutMsg (Send ([|coords2rank (x,y)|], 
                                      InitValue (if (board (x,y)) then
                                                    Live
                                                 else
                                                    Dead)))
               done
              done;
              for x = 0 to xdim-1 do
                for y = 0 to ydim-1 do
                  queueOutMsg (Send ([|coords2rank (x,y)|], 
                                  YourNeighbours (List.map coords2rank (neighbours x y))))
                done
              done;
              sendMsgs ()
            end
          else
            begin
              (* wait until we've gotten the number we've started, and then *)
              (* start more. *)
              if (List.length view' == !numstarted+1) then
                begin 
                  makeSlave ();
                  incr numstarted;
                  [||]
                end
              else 
                [||]
            end
  and exit () = exit 0
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

let init masterEndpt makeSlave rate = 
  life masterEndpt makeSlave rate 

(**************************************************************)
