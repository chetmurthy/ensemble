(**************************************************************)
(* WB.ML *)
(* Authors: Mark Hayden, Robbert vanRenesse, 3/96 *)
(**************************************************************)
open Ensemble
open Tk
open Util
open Appl
open View
open Appl_intf open New
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
  | Xfer of (seqno * coord * coord * coord * coord) array
  | DrawLine of seqno * coord * coord * coord * coord
  | ClearLines
  | ClearAllLines
  | ClearGreyLines
  | PtrSet of coord * coord
  | PtrLeave
  | ProtocolSwitch of Property.id list
      
let string_of_message = function
  | Xfer _ -> "Xfer"
  | DrawLine _ -> "DrawLine"
  | ClearLines -> "CleanLines"
  | ClearAllLines -> "ClearAllLines"
  | ClearGreyLines -> "CleanGreyLines"
  | PtrSet _ -> "PtrSet"
  | PtrLeave -> "PtrLeave"
  | ProtocolSwitch _ -> "ProtocolSwitch"
      
type wrap = 
  | R of message
  | X of string * Property.id list
  | X_Sum of string array * Property.id list option

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
  `Red ;
  `Green	;
  `Color "Yellow" ;
  `Blue ;
  `Color "Brown" ;
  `Color "NavyBlue"
]

(* COLOR_OF_RANK: return the color corresponding to a
 * particular rank.  Above a certain rank, all are black.
 *)
let color_of_rank rank =
  if rank < List.length colors then
    List.nth colors rank
  else `Black

let pix_of_inch x = pixels (`In x)
let pix_of_cm x = pixels (`Cm x)

(**************************************************************)

(* STACK_WIDGET: create a top level widget to prompt the
 * user for the new protocol to use.  It grabs pointer, so
 * we shouldn't have to worry about there being more than
 * one of these.
 *)
let stack_widget top props do_switch =
  let props = ref props in
  let top = Toplevel.create top in
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

  let src = Frame.create 
    ~borderwidth:3 ~height:(pix_of_inch 6.0)
    ~relief:`Sunken ~width:(pix_of_inch 1.5)
    top
  and dst = Frame.create 
    ~borderwidth:3  ~height:(pix_of_inch 6.0)
    ~relief:`Sunken  ~width:(pix_of_inch 1.5) 
    top
  and but_frm = Frame.create top in

  let csb = Button.create 
    ~text:"Switch"
    ~command:(fun () ->
      do_switch !props ;
      destroy top
    )
    but_frm 

  and clb = Button.create 
    ~text:"Cancel"
    ~command:(fun () -> destroy top)
    but_frm 
  in

  (*
   * Labels for the frames.
   *)
  let srclabel = Label.create ~text:"Properties" ~width:20 src in
  let dstlabel = Label.create ~text:"Layers" ~width:20 dst  in

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
      let b = Label.create ~text:name ~relief:`Groove dst in
      stack := (name, b) :: !stack;
      pack ~anchor:`S ~side:`Bottom ~fill:`X [b] 
    ) (List.rev layers)
  in

  let stack_options all props =
    let buttons =
      List.map (fun prop ->
      	let name = Property.string_of_id prop in
      	let but = Checkbutton.create 
      	  ~text:name
      	  ~command:(fun () ->
	    if List.mem prop !props then
	      props := except prop !props
	    else
	      props := prop :: !props ;
            get_protocol ()
	  )
	  src 
	in
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
  pack [srclabel; dstlabel] ;
  pack ~side:`Bottom [but_frm]  ;
  pack ~side:`Right [clb;csb] ;
  pack ~side:`Top ~anchor:`W buttons ;
  pack ~side:`Left [src;dst] ;

  get_protocol () ;
  Tkwait.visibility top ;
  Grab.set top

(**************************************************************)

(* This function returns the interface record that defines
 * the callbacks for the application.
 *)

type state = {
  mutable ls : View.local ;
  mutable vs : View.state ;

  (* A name for each member in the group.
   *)
  mutable names : string array ;
  my_name : string ;

  (* The current properties in use.
   *)
  mutable props: Property.id list ;

  (* This is set below in the handler of the same name.  Get_input
   * calls the installed function to request an immediate callback.
   *)
  async : unit -> unit;
  
  (* This is the last member to have sent data to be output.
   * When another member sends data, we print a prompt for
   * the new source and update this val.
   *)
  mutable last_id : int ;

  (* The seqno for my lines (to use for creating unique id's
   *)
  mutable my_seqno : int ;

  (* This is the buffer used to store typed input prior
   * to sending it.
   *)
  msg_buf : ((wrap, wrap) Ensemble.Appl_intf.action) Queuee.t ;

  (* Pointers is an array containing locations of all the
   * members in the group.
   *)
  mutable pointers : Tk.tagOrId option array ;

  (* Some flags to manage state-transfer
   *)
  mutable blocked : bool ;
  mutable xfer : bool ;

  (* Also, to manage state-transfer
   *)
  mutable sum_states : (string * Property.id list) option array ;
  mutable counter : int 
}

(* To avoid mutablity problems while sending.
 *)
let copy_props s = s.props
(**************************************************************)

let initialize my_name (ls_init, vs_init) = {
  ls = ls_init ;
  vs = vs_init ;
  names = [|my_name|] ;
  my_name = my_name ;
  props = Property.vsync ;
  async = Appl.async (vs_init.group,ls_init.endpt) ;
  last_id = -1;
  my_seqno = 0;
  msg_buf = Queuee.create () ;
  pointers = [||] ;
  blocked = false ;
  xfer = false ;
  sum_states = Array.create 1 None ;
  counter = 0
}

let intf s alarm top =
  let msg_action a = 
    Queuee.add a s.msg_buf ;
    s.async () 
(*    Alarm.schedule (Alarm.alarm alarm (fun _ ->())) (Time.zero) ;*)
  in
  let msg_cast m = msg_action (Cast (R m)) in

  (* CHECK_BUF: If there is buffered data, then return
   * actions to send them (after packing them).
   *)
  let check_buf () =
    let send = Queuee.to_array s.msg_buf in
    Queuee.clear s.msg_buf ;
(*    if Array.length send > 0 then 
      log (fun () -> sprintf "len=%d" (Array.length send));*)
    send
  in

  let main = Frame.create top in

  (* Create the widgets and pack them.
   *)
  let menu_frm	= Frame.create ~borderwidth:2 ~relief:`Raised main in
  let clear_mb	= Menubutton.create ~text:"Clear" menu_frm in
  let proto_mb  = Menubutton.create ~text:"Action" menu_frm in
  let xfer_but =  Checkbutton.create ~text:"Xfer" ~relief:`Groove menu_frm in
  Checkbutton.deselect xfer_but ;

  let status_frm = Frame.create ~borderwidth:2 ~relief:`Groove main in
  let proto_lab = Label.create status_frm in
  let trans_lab = Label.create status_frm in
  let key_lab   = Label.create status_frm in

  let body_frm	= Frame.create main in

  let wb_frm    = Frame.create 
    ~borderwidth:3 
    ~relief:`Raised
    body_frm in

  let wb_cv 	= Canvas.create 
    ~borderwidth:3
    ~background:`White 
    ~height:(pix_of_inch 2.5)
    ~width:(pix_of_inch 2.5)
    wb_frm in

  (* Initialize the membership frame.
   *)
  let mbr_frm	= Frame.create body_frm in
  let mbr_lbl   = Label.create ~text:"Membership" mbr_frm in
  let mbr_lb	= Listbox.create ~height:8 mbr_frm in

  pack ~side:`Left ~anchor:`Nw 
    [
      coe wb_frm;
      coe wb_cv
    ] ;

  pack ~side:`Left 
    [
      coe clear_mb;
      coe proto_mb;
      coe xfer_but
    ];

  pack 
    ~anchor:`Nw ~side:`Top   
    ~padx:(pix_of_cm 0.2) ~pady:(pix_of_cm 0.1) 
    [
      mbr_frm;
      menu_frm;
      status_frm;
      body_frm
    ] ;


  pack ~anchor:`Nw ~side:`Top
    ~padx:(pix_of_cm 0.05) ~pady:(pix_of_cm 0.05) 
    [
      proto_lab;
      trans_lab;
      key_lab
    ];

  pack ~anchor:`Nw ~side:`Top 
    [
      coe mbr_lbl;
      coe mbr_lb
    ] ;

  pack ~side:`Left ~anchor:`Nw 
    [main] 
  ;

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
	let rank = Arrayf.index who s.vs.view in
	color_of_rank rank
      with Not_found -> (
        `Color "Grey"
      )
    in
    let line = Canvas.create_line 
      ~xys:[x1,y1 ; x2,y2] ~fill:color ~width:3 
      wb_cv 
    in {
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
    let view = Arrayf.to_list s.vs.view in
    drag_filt (fun {from=from} -> List.mem from view)
  in

  let delete_all_lines () =
    drag_filt (fun _ -> false)
  in

  (* PTR_RESET: Remove everyone's pointers from the canvass.
   *)
  let ptr_reset nmembers =
    Array.iter (function
    | Some obj  -> Canvas.delete wb_cv [obj]
    | None -> ()
    ) s.pointers ;
    s.pointers <- Array.create nmembers None
  in

  (* PTR_SET: Update one of the other member's pointers.
   *)
  let ptr_set rank x y =
     if_some s.pointers.(rank) (fun obj ->
       Canvas.delete wb_cv [obj]
     ) ;
    let name = s.names.(rank) in
    let obj = Canvas.create_text 
      ~x:(x) ~y:(y) ~text:name 
      wb_cv
    in
    s.pointers.(rank) <- Some obj
  in

  (* PTR_LEAVE: Remove a member's pointer from the canvass.
   *)
  let ptr_leave rank =
    match s.pointers.(rank) with
    | Some obj -> (
      	Canvas.delete wb_cv [obj] ;
	s.pointers.(rank) <- None
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
	  msg_cast (DrawLine(s.my_seqno,x1,y1,x2,y2)) ;
	  add_line s.ls.endpt s.my_seqno x1 y1 x2 y2 ;
	  s.my_seqno <- succ s.my_seqno
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
	  log (fun () -> "cast draw_line");
	  msg_cast (DrawLine(s.my_seqno,x1,y1,x2,y2)) ;
	  add_line s.ls.endpt s.my_seqno x1 y1 x2 y2 ;
	  s.my_seqno <- succ s.my_seqno
	)
      | None -> ()
    end ;
    drag_pos := None
  in

  let protocol_switch props' =
    s.props <- props' ;
    let proto_id = Property.choose s.props in
    msg_action (Control(Protocol(proto_id))) ;	(* install the protocol locally *)
    msg_cast (ProtocolSwitch(props')) ;	(* broadcast the switch *)
  in

  let switch_press _ =
    stack_widget top s.props protocol_switch
  in

  let rekey_press _ =
    msg_action (Control (Rekey false))
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
    delete_lines s.ls.endpt
  in

  (* Configure the protocol menu.
   *)
  let proto_menu = Menu.create proto_mb in
  Menu.add_command ~command:switch_press ~label:"Switch Stack" proto_menu ;
  Menu.add_command ~command:rekey_press ~label:"Rekey" proto_menu ;
  Menubutton.configure ~menu:proto_menu proto_mb ;

  (* Configure the clear menu.
   *)
  let clear_menu = Menu.create clear_mb in
  Menu.add_command ~label:"Clear All"  ~command:clear_all_press clear_menu;
  Menu.add_command ~label:"Clear Mine" ~command:clear_press clear_menu;
  Menu.add_command ~label:"Clear Grey" ~command:clear_grey_press  clear_menu;
  Menubutton.configure ~menu:clear_menu clear_mb ;

  (* Bind above functions to various events.
   * TODO: this should be cleaned up.
   *)
  bind ~events:[(*[Button1],*) `Motion] ~fields:[`MouseX; `MouseY]
    ~action:drag_moved wb_cv ;
  bind ~events:[(*[Button1],*)	`ButtonPress] 	~fields:[`MouseX; `MouseY]
    ~action:drag_begin wb_cv ;
  bind ~events:[(*[Button1],*)	`ButtonRelease]  ~fields:[`MouseX; `MouseY]
    ~action:drag_end wb_cv ;
  bind ~events:[(*[Button1],*) `Enter] ~fields:[`MouseX; `MouseY]
    ~action:drag_begin wb_cv ;
  bind ~events:[(*[Button1],*) `Leave] ~fields:[`MouseX; `MouseY]
    ~action:drag_end wb_cv ;
  bind ~events:[`Motion] ~fields:[`MouseX; `MouseY]
    ~action:mouse_move wb_cv ;
  bind ~events:[`Leave]	~action:mouse_leave wb_cv ;

  (* Process a message from someone else.
   *)
  let recv_msg origin msg =
    if origin <> s.ls.rank then (
      let from = Arrayf.get s.vs.view origin in
      match msg with
      | DrawLine(seqno,x1,y1,x2,y2) ->
	  log (fun () -> "recv draw_line");
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
      | ProtocolSwitch props ->
	  s.props <- props ;
	  let proto_id = Property.choose props in
	  msg_action (Control (Protocol(proto_id))) (* install the protocol locally *)
    )
  in


  (* 
   * Recolor all the lines according to new ranks.
   *)
  let receive_x_sum (ls,vs) names' props' = 
    s.xfer  <- false ;
    s.sum_states <- Array.create 0 None;
    s.counter <- 0;
    s.names <- names' ;
    s.ls <- ls ;
    s.vs <- vs ;

    if_some props' (fun props' ->	(*HACK*)
      s.props <- props'
    );
    
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
      	if who = s.ls.endpt then (
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
      Listbox.delete mbr_lb (`Num 0) `End ;
      Listbox.insert mbr_lb (`Num 0) (Array.to_list s.names);
    );

    (* Update the pointers to new view size.
     *)
    ptr_reset (Arrayf.length vs.view) ;
    
    (* Print current protocol in use.
     *)
    let props_s = List.map Property.string_of_id s.props in
    let props_s = String.concat ":" props_s in
    
    Label.configure ~text:("Properties: "^props_s) proto_lab ;
    
    (* Print available protocols in this view. 
     *)
    let modes = Addr.modes_of_view vs.address in
    let modes = Arrayf.map Addr.string_of_id modes in
    let modes = String.concat ":" (Arrayf.to_list modes) in
    Label.configure ~text:("Transports: "^modes) trans_lab ;
    
    (* Print security key in use.
     *)
    let key = Security.string_of_key_short vs.key in
    Label.configure ~text:("Key: "^key) key_lab ;

    Array.append (check_buf ()) [|Control XferDone|]
  in
  
  
  let install (ls,vs) = 
    log (fun () -> sprintf "install nmembers=%d\n" ls.nmembers);
    s.blocked <- false ;

    let actions = 
      if ls.nmembers > 1 then (
	s.xfer <- true ;
	s.sum_states <- Array.create ls.nmembers None ;
	s.sum_states.(ls.rank) <- Some(s.my_name, s.props);
	s.counter <- 1;
	if ls.rank = 0 then [||]
	else [|Send1 (0, X (s.my_name,copy_props s))|]
      ) else (
	receive_x_sum (ls,vs) s.names (Some s.props)
      )
    in


    let receive origin _ _ msg =
      match msg with 
	  R msg -> 
	    if not s.blocked && not s.xfer then (
	      recv_msg origin msg ;
	      check_buf ()
	    ) else (
	      recv_msg origin msg ;
	      [||]
	    )
	| X (name,props) -> 
	    assert (ls.rank = 0);
	    s.sum_states.(origin) <- Some(name,props);
	    s.counter <- succ s.counter;
	    if s.counter = ls.nmembers then
	      let info = Array.map (function
		  None -> failwith "some_of" 
		| Some x -> x
	      ) s.sum_states in
	      let names = Array.map fst info in
	      let props = Array.map snd info in
	      let props = 
		Array.fold_left (fun res props ->
		  if Property.choose props = s.vs.proto_id then
		    Some props
		  else res
		) None props
	      in
	      let msgs = receive_x_sum (ls,vs) names props in
	      if not s.blocked then 
		Array.append [|Cast (X_Sum (names,props))|] msgs
	      else
		[||]
	    else
	      [||]
	| X_Sum (names,props) -> 
	    if ls.rank <> 0 then 
	      receive_x_sum (ls,vs) names props
	    else
	      [||]
		
    and block () = 
      s.blocked <- true;
      [||]
      
    and heartbeat _ =
      if not s.blocked && not s.xfer then (
	(*log (fun () -> "heartbeat");*)
	check_buf ()
      ) else [||]

    in actions, {
      flow_block = (fun _ -> ());
      receive = receive ;
      block = block ;
      heartbeat = heartbeat ;
      disable = (fun _ -> ())
    }

  and exit () =
    printf "exiting\n"

  in full {
    heartbeat_rate      = Time.of_int 3 ;
    install             = install ;
    exit                = exit 
  }

(**************************************************************)

let run () =
  (* Set defaults for domain and alarm.
   *)
  Arge.set_string Arge.alarm "Tk" ;
  Param.default "stable_sweep" (Param.Time (Time.of_float 0.5)) ;
  Param.default "suspect_sweep" (Param.Time (Time.of_float 0.5)) ;
(*  Param.default "suspect_max_idle" (Param.Int 4) ;
  Param.default "merge_timeout" (Param.Time (Time.of_float 8.0)) ;
*)

  (* Parse command line arguments.
   *)
  Arge.parse [
  ] (Arge.badarg name) "" ; 

  (* Choose a string name for this member.  Usually
   * this is "userlogin@host".
   *)
  let username =
    try
      (Hsys.getlogin ()) ^ "@" ^ (Hsys.gethostname ())
    with _ ->
      ("unknown")
  in

  let top = Tk.openTk () in
  let (ls,vs) = Appl.default_info "wb" in
  let alarm = Alarm.get_hack () in
  let state = initialize username (ls,vs) in
  let interface = intf state alarm top in
  Appl.config_new interface (ls,vs) ;

  Htk.init alarm;
  Tk.mainLoop ()

(**************************************************************)
(* Run the application, with exception handlers to catch any
 * problems that might occur.
 *)
let _ = Printexc.catch run ()

(* Flush output and exit the process.
 *)
let _ = exit 0

(**************************************************************)


