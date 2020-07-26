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
(* WB.ML *)
(* Authors: Mark Hayden, Robbert vanRenesse, 3/96 *)
(**************************************************************)
open Ensemble
open Tk
open Util
open Appl
open View
open Appl_intf open Old
open Proto
(**************************************************************)
let name = Trace.file "WB"
let failwith s = Trace.make_failwith name s
let log = Trace.log name
(**************************************************************)

type coord = int
type seqno = int

(**************************************************************)

(* MESSAGE: the type of messages sent by this application.
 *)
type message =
| DrawLine of seqno * coord * coord * coord * coord
| Xfer of (seqno * coord * coord * coord * coord) array
| ClearLines
| ClearAllLines
| ClearGreyLines
| PtrSet of coord * coord
| PtrLeave
| ProtocolSwitch of Property.id list

(**************************************************************)

(* LINE: contains info about lines we are currently
 * displaying.
 *)
type line = {
  from : Endpt.id ;
  seqno : seqno ;
  x1 : coord ;
  y1 : coord ;
  x2 : coord ;
  y2 : coord ;
  obj : Tk.tagOrId
}

(**************************************************************)

let colors = [
  Red ;
  Green	;
  NamedColor "Yellow" ;
  Blue ;
  NamedColor "Brown" ;
  NamedColor "NavyBlue"
]

(* COLOR_OF_RANK: return the color corresponding to a
 * particular rank.  Above a certain rank, all are black.
 *)
let color_of_rank rank =
  if rank < List.length colors then
    List.nth colors rank
  else Black

(**************************************************************)

(* STACK_WIDGET: create a top level widget to prompt the
 * user for the new protocol to use.  It grabs pointer, so
 * we shouldn't have to worry about there being more than
 * one of these.
 *)
let stack_widget top props do_switch =
  let props = ref props in
  let top = Toplevel.create top [] in
  Focus.set top ;
  Wm.title_set top "Protocol Switch" ;

  (*
   * We maintain a mutable list which represents the
   * protocol stack.  Each entry is a pair (name of layer,
   * button widget), where the widget represents the layer
   * on the screen.  The top protocol appears first in the
   * list.
   *)
  let stack = ref [] in

  (*
   * The toplevel frame contains two subframes, src and dst,
   * and three buttons, csb, dsb, and clb.  src will contain
   * the list of layers that we support, and dst the
   * protocol stack.  csb is the create_stack button, dsb
   * the destroy_stack button, and clb the close button
   * which closes this frame.
   *)
  let src = Frame.create top [
    Relief Sunken; BorderWidth (Pixels 3) ;
    Width (Inches 1.5); Height (Inches 6.0)
  ]
  and dst = Frame.create top [
    Relief Sunken; BorderWidth (Pixels 3) ;
    Width (Inches 1.5); Height (Inches 6.0)
  ]
  and but_frm = Frame.create top [] in

  let csb = Button.create but_frm [
    Text "Switch" ;
    Command (fun () ->
      do_switch !props ;
      destroy top
    )
  ]
  and clb = Button.create but_frm [
    Text "Cancel" ;
    Command (fun () -> destroy top)
  ]
  in

  (*
   * Labels for the frames.
   *)
  let srclabel = Label.create src [ Text "Properties"; Width (Pixels 20) ] in
  let dstlabel = Label.create dst [ Text "Layers"; Width (Pixels 20) ] in

  (*
   * The frames are fixed size.
   *)
  Pack.propagate_set src false;
  Pack.propagate_set dst false;

  (*
   * This function creates a button in the layer list.  When
   * the button is pushed, a button gets stacked on top the
   * current stack, and added to the stack list.
   *)
  let get_protocol () =
    let proto = Property.choose !props in
    let proto = Proto.layers_of_id proto in
    let layers = List.map string_of_l proto in

    List.iter (fun l -> destroy (snd l)) !stack ;
    stack := [] ;
    
    List.iter (fun name ->
      let b = Label.create dst [Text name; Relief Groove] in
      stack := (name, b) :: !stack;
      pack [b][Anchor S; Side Side_Bottom; Fill Fill_X]
    ) (List.rev layers)
  in

  let stack_options all props =
    let buttons =
      List.map (fun prop ->
      	let name = Property.string_of_id prop in
      	let but = Checkbutton.create src [
      	  Command (fun () ->
	    if List.mem prop !props then
	      props := except prop !props
	    else
	      props := prop :: !props ;
            get_protocol ()
	  ) ;
      	  Text name
      	] in
      	if List.mem prop !props then
      	  Checkbutton.select but
      	else
      	  Checkbutton.deselect but ;
      	but
      ) all
    in (props,buttons)
  in

  let all = [
    Property.Total ;
    Property.Heal ;
    Property.Subcast ;
    Property.Debug ;
    Property.Xfer ;
    Property.Scale ;
    Property.Auth ;
    Property.Privacy ;
    Property.Rekey ;
    Property.Flow
  ] in
  let (props,buttons) = stack_options all props in

  (*
   * Pack everything.
   *)
  pack [srclabel; dstlabel][] ;
  pack [but_frm][Side Side_Bottom] ;
  pack [clb;csb][Side Side_Right] ;
  pack buttons [Side Side_Top;Anchor W] ;
  pack [src;dst] [Side Side_Left] ;

  get_protocol () ;
  Tkwait.visibility top ;
  Grab.set top

(**************************************************************)

(* This function returns the interface record that defines
 * the callbacks for the application.
 *)

let intf (ls_init,vs_init) my_name alarm top do_migrate =

  (* The current properties in use.
   *)
  let props = ref Property.vsync in
  let my_endpt = ls_init.endpt in
  
  (* The current view of the group.
   *)
  let view	= ref [||] in

  (* This is an association list of (endpt,string name) for every
   * member in the group.
   *)
  let names 	= ref [|my_name|] in

  (* This is set below in the handler of the same name.  Get_input
   * calls the installed function to request an immediate callback.
   *)
  let async = Appl.async (vs_init.group,ls_init.endpt) in
  
  (* This is the last member to have sent data to be output.
   * When another member sends data, we print a prompt for
   * the new source and update this val.
   *)
  let last_id = ref (-1) in

  (* My rank in the group
   *)
  let rank = ref (-1) in

  (* The seqno for my lines (to use for creating unique id's
   *)
  let seqno = ref 0 in

  (* This is the buffer used to store typed input prior
   * to sending it.
   *)
  let msg_buf = Queuee.create () in
  let msg_action a = 
    async () ;
    Alarm.schedule (Alarm.alarm alarm (fun _ ->())) (Time.zero) ;
    Queuee.add a msg_buf 
  in
  let msg_cast m = msg_action (Cast(m)) in

  (* CHECK_BUF: If there is buffered data, then return
   * actions to send them (after packing them).
   *)
  let check_buf () =
    let send = Queuee.to_list msg_buf in
    Queuee.clear msg_buf ;
    Array.of_list send
  in

  (* Pointers is an array containing locations of all the
   * members in the group.
   *)
  let pointers = ref [||] in
  
  let main = Frame.create top [] in

  (* Create the widgets and pack them.
   *)
  let menu_frm	= Frame.create main [BorderWidth (Pixels 2); Relief Raised] in
  let clear_mb	= Menubutton.create menu_frm [Text "Clear"] in
  let proto_mb  = Menubutton.create menu_frm [Text "Action"] in
  let xfer_but =  Checkbutton.create menu_frm [Text "Xfer"; Relief Groove] in
  Checkbutton.deselect xfer_but ;

  let status_frm = Frame.create main [BorderWidth (Pixels 2); Relief Groove] in
  let proto_lab = Label.create status_frm [] in
  let trans_lab = Label.create status_frm [] in
  let key_lab   = Label.create status_frm [] in

  let body_frm	= Frame.create main [] in

  let wb_frm    = Frame.create body_frm [
    BorderWidth (Pixels 3);
    Relief Raised
  ] in

  let wb_cv 	= Canvas.create wb_frm [
    BorderWidth (Pixels 3);
    Background White ;
    Height (Inches 2.5) ;
    Width (Inches 2.5)
  ] in

  (* Initialize the membership frame.
   *)
  let mbr_frm	= Frame.create body_frm [] in
  let mbr_lbl   = Label.create mbr_frm [Text "Membership"] in
  let mbr_lb	= Listbox.create mbr_frm [TextHeight 8] in

  pack [
    wb_frm;
    wb_cv
  ] [
    Side Side_Left;
    Anchor NW
  ] ;

  pack [
    clear_mb;
    proto_mb;
    xfer_but
  ] [
    Side Side_Left
  ] ;

  pack [
    mbr_frm;
    menu_frm;
    status_frm;
    body_frm
  ] [
    Side Side_Top;
    PadX (Millimeters 2.);
    PadY (Millimeters 1.);
    Anchor NW
  ] ;

  pack [
    proto_lab;
    trans_lab;
    key_lab
  ] [
    Side Side_Top;
    PadX (Millimeters 0.5);
    PadY (Millimeters 0.5);
    Anchor NW
  ] ;

  pack [
    mbr_lbl;
    mbr_lb
  ] [
    Side Side_Top ;
    Anchor NW
  ] ;

  pack [main] [
    Side Side_Left;
    Anchor NW
  ] ;

  (* Drag_pos is the current position of the mouse on the
   * canvass.
   *)
  let drag_pos = ref None in
  let drag_lines = ref [] in
  let drag_find who seqno =
    let rec loop = function
    | [] -> false
    | {from=who';seqno=seqno'}::_
      when who=who' & seqno=seqno' -> true
    | _::tl -> loop tl
    in loop !drag_lines
  and drag_add obj =
    drag_lines := obj :: !drag_lines
  and drag_filt test =
    let rec loop = function
    | [] -> []
    | line::tl ->
      	if test line then
      	  line :: (loop tl)
	else (
	  Canvas.delete wb_cv [line.obj] ;
      	  loop tl
	)
    in drag_lines := loop !drag_lines
  in

  (* DRAW_LINE: actually draw a line on the canvass (and return
   * a line object)
   *)
  let draw_line who seqno x1 y1 x2 y2 =
    let color =
      try
	let rank = array_index who !view in
	color_of_rank rank
      with Not_found -> (
        NamedColor "Grey"
      )
    in
    let line = Canvas.create_line wb_cv [
      Pixels x1;
      Pixels y1;
      Pixels x2;
      Pixels y2
    ] [FillColor color; Width (Pixels 3)] in {
      from = who ;
      seqno = seqno ;
      x1=x1; y1=y1; x2=x2; y2=y2;
      obj = line
    }
  in

  (* Some helper functions.
   *)
  let add_line who seqno x1 y1 x2 y2 =
    if not (drag_find who seqno) then (
      drag_add (draw_line who seqno x1 y1 x2 y2)
    )
  in

  let delete_lines from =
    drag_filt (fun {from=from'} -> from <> from')
  in

  let delete_grey_lines () =
    let view = Array.to_list !view in
    drag_filt (fun {from=from} -> List.mem from view)
  in

  let delete_all_lines () =
    drag_filt (fun _ -> false)
  in

  (* PTR_RESET: Remove everyone's pointers from the canvass.
   *)
  let ptr_reset nmembers =
    Array.iter (function
    | Some obj -> Canvas.delete wb_cv [obj]
    | None -> ()
    ) !pointers ;
    pointers := Array.create nmembers None
  in

  (* PTR_SET: Update one of the other member's pointers.
   *)
  let ptr_set rank x y =
     if_some !pointers.(rank) (fun obj ->
       Canvas.delete wb_cv [obj]
     ) ;
    let name = !names.(rank) in
    let obj = Canvas.create_text wb_cv
      (Pixels x) (Pixels y) [Text name]
    in
    !pointers.(rank) <- Some obj
  in

  (* PTR_LEAVE: Remove a member's pointer from the canvass.
   *)
  let ptr_leave rank =
    match !pointers.(rank) with
    | Some obj -> (
      	Canvas.delete wb_cv [obj] ;
	!pointers.(rank) <- None
      )
    | None -> ()
  in

  let mouse_move ev =
    let x = ev.Tk.ev_MouseX in
    let y = ev.Tk.ev_MouseY in
    msg_cast (PtrSet(x,y))
  in

  let mouse_leave ev =
    msg_cast PtrLeave
  in

  let drag_moved ev =
    let x2 = ev.Tk.ev_MouseX in
    let y2 = ev.Tk.ev_MouseY in
    mouse_move ev ;			(* hack! *)
    begin
      match !drag_pos with
      | Some(x1,y1) -> (
	  msg_cast (DrawLine(!seqno,x1,y1,x2,y2)) ;
	  add_line my_endpt !seqno x1 y1 x2 y2 ;
	  incr seqno
	)
      | None -> ()
    end ;
    drag_pos := Some(x2,y2)
  in

  let drag_begin ev =
    let x2 = ev.Tk.ev_MouseX in
    let y2 = ev.Tk.ev_MouseY in
    drag_pos := Some(x2,y2)
  in

  let drag_end ev =
    let x2 = ev.Tk.ev_MouseX in
    let y2 = ev.Tk.ev_MouseY in
    begin
      match !drag_pos with
      | Some(x1,y1) -> (
	  msg_cast (DrawLine(!seqno,x1,y1,x2,y2)) ;
	  add_line my_endpt !seqno x1 y1 x2 y2 ;
	  incr seqno
	)
      | None -> ()
    end ;
    drag_pos := None
  in

  let protocol_switch props' =
    props := props' ;
    let proto_id = Property.choose !props in
    msg_action (Control(Protocol(proto_id))) ;	(* install the protocol locally *)
    msg_cast (ProtocolSwitch(!props)) ;	(* broadcast the switch *)
  in

  let switch_press _ =
    stack_widget top !props protocol_switch
  in

  let migrate_press _ =
    let addr = do_migrate "gulag" in
    msg_action (Control(Migrate(addr)))
  in

  let rekey_press _ =
()(* Not supported right now.
    msg_action (Control Rekey)
*)
  in

  (* Reactions for various button presses.
   *)
  let clear_all_press _ =
    msg_cast ClearAllLines ;
    delete_all_lines ()
  in

  let clear_grey_press _ =
    msg_cast ClearGreyLines ;
    delete_grey_lines ()
  in

  let clear_press _ =
    msg_cast ClearLines ;
    delete_lines my_endpt
  in

  (* Configure the protocol menu.
   *)
  let proto_menu = Menu.create proto_mb [] in
  Menu.add_command proto_menu [Label "Switch Stack"; Command switch_press] ;
  Menu.add_command proto_menu [Label "Migrate"; Command migrate_press] ;
  Menu.add_command proto_menu [Label "Rekey"; Command rekey_press] ;
  Menubutton.configure proto_mb [Menu proto_menu] ;

  (* Configure the clear menu.
   *)
  let clear_menu = Menu.create clear_mb [] in
  Menu.add_command clear_menu [Label "Clear All";  Command clear_all_press] ;
  Menu.add_command clear_menu [Label "Clear Mine"; Command clear_press] ;
  Menu.add_command clear_menu [Label "Clear Grey"; Command clear_grey_press] ;
  Menubutton.configure clear_mb [Menu clear_menu] ;

  (* Bind above functions to various events.
   * TODO: this should be cleaned up.
   *)
  bind wb_cv [[Button1],	Motion] 	(BindSet([Ev_MouseX; Ev_MouseY],drag_moved)) ;
  bind wb_cv [[Button1],	ButtonPress] 	(BindSet([Ev_MouseX; Ev_MouseY],drag_begin)) ;
  bind wb_cv [[Button1],	ButtonRelease] 	(BindSet([Ev_MouseX; Ev_MouseY],drag_end)) ;
  bind wb_cv [[Button1],	Enter] 		(BindSet([Ev_MouseX; Ev_MouseY],drag_begin)) ;
  bind wb_cv [[Button1],	Tk.Leave]       (BindSet([Ev_MouseX; Ev_MouseY],drag_end)) ;
  bind wb_cv [[],		Motion]		(BindSet([Ev_MouseX; Ev_MouseY],mouse_move)) ;
  bind wb_cv [[],		Tk.Leave]	(BindSet([],mouse_leave)) ;

  (* Process a message from someone else.
   *)
  let recv_msg origin msg =
    if origin <> !rank then (
      let from = !view.(origin) in
      match msg with
      | DrawLine(seqno,x1,y1,x2,y2) ->
         add_line from seqno x1 y1 x2 y2
      | Xfer(lines) ->
	    Array.iter (fun (seqno,x1,y1,x2,y2) ->
	      add_line from seqno x1 y1 x2 y2
	    ) lines
      | ClearAllLines 	-> delete_all_lines ()
      | ClearGreyLines 	-> delete_grey_lines ()
      | ClearLines 	-> delete_lines from
      | PtrSet(x,y) ->
	    ptr_set origin x y
      | PtrLeave ->
	    ptr_leave origin
      | ProtocolSwitch props' ->
	  props := props' ;
	  let proto_id = Property.choose !props in
	  msg_action (Control (Protocol(proto_id))) (* install the protocol locally *)
    )
  in

  let recv_cast origin msg =
    recv_msg origin msg ;
    check_buf ()
  and recv_cast_iov _ _ = failwith "recv_cast_iov"

  and recv_send _ _ = failwith "error"
  and block () = [||]
  and heartbeat _ =
    check_buf ()

  and block_recv_cast origin msg =
    recv_msg origin msg
  and block_recv_cast_iov _ _ = failwith "block_recv_cast_iov"
  and block_recv_send _ _ = ()
  and block_view (ls,vs) =
    [ls.rank,(my_name,!props)]
  and block_install_view (ls',vs') info =
    let names = List.map fst info in
    let props = List.map snd info in
    let props = 
      List.fold_left (fun res props ->
        if Property.choose props = vs'.proto_id then
          Some props
        else res
      ) None props
    in
    (props,names)
  and unblock_view (ls,vs) (props',names') =
    names       := Array.of_list names' ;
    view 	:= Arrayf.to_array vs.view ;
    rank 	:= ls.rank ;
    if_some props' (fun props' ->	(*HACK*)
      props       := props'
    ) ;
     
    (* If state transfer view, then multicast all of my
     * active lines.  If not then recolor all the lines
     * according to new ranks.
     *)
    if vs.xfer_view then (
      Checkbutton.select xfer_but ;

      (* Get my entries from the list.
       *)
      let xfer = ref [] in
      List.iter (fun {from=who;seqno=seqno;x1=x1;y1=y1;x2=x2;y2=y2} ->
      	if who = my_endpt then (
	  xfer := (seqno,x1,y1,x2,y2) :: !xfer
	)
      ) !drag_lines ;

      let xfer = Array.of_list !xfer in
      msg_cast(Xfer(xfer))
    ) else (
      Checkbutton.deselect xfer_but ;

      (* Redraw all the lines with new coloring.
       *)
      drag_lines := List.map (fun {from=who;seqno=seqno;x1=x1;y1=y1;x2=x2;y2=y2;obj=line} ->
  	Canvas.delete wb_cv [line] ;
	draw_line who seqno x1 y1 x2 y2
      ) !drag_lines ;

      (* Update the group view information.
       *)
      Listbox.delete mbr_lb (Number 0) End ;
      Listbox.insert mbr_lb (Number 0) (Array.to_list !names)
    ) ;

    (* Update the pointers to new view size.
     *)
    ptr_reset (Arrayf.length vs.view) ;

    (* Print current protocol in use.
     *)
    let props_s = List.map Property.string_of_id !props in
    let props_s = String.concat ":" props_s in
     
    Label.configure proto_lab [Text ("Properties: "^props_s)] ;

    (* Print available protocols in this view. 
     *)
    let modes = Addr.modes_of_view vs.address in
    let modes = Arrayf.map Addr.string_of_id modes in
    let modes = String.concat ":" (Arrayf.to_list modes) in
    Label.configure trans_lab [Text ("Transports: "^modes)] ;

    (* Print security key in use.
     *)
    let key = Security.string_of_key_short vs.key in
    Label.configure key_lab [Text ("Key: "^key)] ;

    Array.append (check_buf ()) [|Control XferDone|]

  and exit () =
    printf "exiting\n"

  in {
    recv_cast           = recv_cast ;
    recv_send           = recv_send ;
    heartbeat           = heartbeat ;
    heartbeat_rate      = (Time.of_int 10) ;
    block               = block ;
    block_recv_cast     = block_recv_cast ;
    block_recv_send     = block_recv_send ;
    block_view          = block_view ;
    block_install_view  = block_install_view ;
    unblock_view        = unblock_view ;
    exit                = exit
  }

(**************************************************************)

let init top view_state username do_migrate =
  let ready_to_migrate = ref None in

  let do_migrate host_name =
    let addr,got_vs = do_migrate host_name in
    ready_to_migrate := Some got_vs ;
    addr
  in

  (* Initialize the application interface.
   *)
  let alarm = Elink.alarm_get_hack () in
  let interface = intf view_state username alarm top do_migrate in
  
  let up ev =
    match Event.getType ev with
    | Event.EView -> (
        let vs = Event.getViewState ev in
        match !ready_to_migrate with
        | Some got_vs ->
            got_vs vs
        | None -> 
            eprintf "WB:ready to migrate, but no function\n" ;
            exit 0
      )
    | _ -> ()
  in

  (* Initialize the protocol stack, using the
   * interface, protocol stack, and transports chosen above.
   *)
  let mbuf = Alarm.mbuf alarm in
  let interface = Elink.get_appl_old_full name interface in
  let interface = Elink.get name Elink.appl_compat_compat interface in
  let interface = Elink.get_appl_power_newf name mbuf interface in
  let glue = Arge.get Arge.glue in
  let state = Layer.new_state interface in
  let dn = Stacke.config_full glue alarm Addr.default_ranking state view_state up in
  ()

(**************************************************************)
