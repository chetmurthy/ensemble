open Rules
open Msgs
open Tk
open Printf

let unit _ = ()

(* callbacks *)
let computedCellsFunc = ref (fun _ -> [])

let setComputedCellsCallback f = (computedCellsFunc := f)

let numberCellsComputedCallback = ref (fun _ -> 0)

let setNumberCellsComputedCallback f = numberCellsComputedCallback := f

let startFunc = ref (fun _ -> fun _ -> fun _ -> fun _ -> ())

let setStartCallback f = startFunc := f

(* holds the global state of the main display *)
type graphicState = Starting
                  | MainDisplay of 
		      (Widget.canvas Widget.widget *   (* the canvas display *)
                      Widget.label Widget.widget list * (* list of gen counters *)
                      int *  (* generation being displayed *)
                      Widget.label Widget.widget * (* label showing generation # *)
                      Widget.label Widget.widget)  (* label showing endpoints *)

let state = ref Starting

(* maps cell states to the colors that they will be displayed as *)

let cellColors = [(Bottom, `Color "grey");
                  (Live, `Color "blue");
                  (Dead, `Color "black")]

let cellstate2color c = List.assoc c cellColors

let mapbool2color b = if b then
                         cellstate2color Live
                      else
                         cellstate2color Dead

(* how big in pixels each cell will be displayed *)
let cellSize = 15

(* the variable holding the number of endpoints in the current view *)
(* this is a ref, because it cannot be initialized until Tk itself has *)
(* been initialized.  Growl. *)

let viewVariable = ref None

let getViewVariable () =
  match !viewVariable with
    Some x -> x
    | _ -> raise (Match_failure("",0,0))


(* ---------------------------------------------------------------*)

(* Functions for main display *)

let boardcanvas () = match !state with
   MainDisplay (c,_,_,_,_) -> c
   | _ -> raise (Match_failure("",0,0))

let gencounters () = match !state with
   MainDisplay (_,g,_,_,_) -> g
   | _ -> raise (Match_failure("",0,0))

let currentGen () = match !state with
   MainDisplay (_,_,s,_,_) -> s
   | _ -> raise (Match_failure("",0,0))

let setCurrentGen cg =
  match !state with
    MainDisplay (c, g, _, gd, ec) -> state := MainDisplay(c,g,cg,gd,ec)
    | _ -> raise (Match_failure("",0,0))

let generationDisplay () = match !state with
   MainDisplay (_,_,_,gd,_) -> gd
   | _ -> raise (Match_failure("",0,0))

let endpointCounter () = match !state with
   MainDisplay (_,_,_,_,ec) -> ec
   | _ -> raise (Match_failure("",0,0))

let paintCell x y c =
   Canvas.create_rectangle
     ~x1:(cellSize*x)            
     ~y1:(cellSize*y)
     ~x2:(cellSize*x+cellSize-1) 
     ~y2:(cellSize*y+cellSize-1)
     ~fill:(cellstate2color c)
     ~width:0
     ~tags:["pixels"]
     (boardcanvas ()) 

let setGenerationMsg g m =
    Label.configure ~text:m (List.nth (gencounters ()) g)

let initializeGenCounters maxgen parent pressfunc genvariable =
  let rec range i limit = if i == limit then
                          [i]
                       else
                          i :: (range (i+1) limit)
  in
     let titleframe = Frame.create parent
     and genframes =  List.map (function g ->
       Frame.create 
       ~borderwidth:1
       ~relief:`Raised
       parent 
     ) (range 0 maxgen)
     in
       pack ~side:`Left [titleframe];
       pack ~side:`Left genframes;
       pack ~side:`Top [Label.create ~text:"generation" titleframe] ;
       pack ~side:`Top [Label.create ~text:"computed" titleframe] ;
       pack ~side:`Top [Label.create ~text:"" titleframe] ;
       List.map (function g ->
         let thisframe = List.nth genframes g in
         pack ~side:`Top [Label.create ~text:(string_of_int g) thisframe];
	 let thisCounter = Label.create ~text:"0"  thisframe in
         pack ~side:`Top [thisCounter];
         pack ~side:`Top 
	   [Radiobutton.create 
             ~variable:genvariable
             ~value:(string_of_int g)
             ~command:(pressfunc g)
	     thisframe
	   ];
         thisCounter
       )
         (range 0 maxgen)

let displayGeneration canvas g =
  if g = currentGen () then
    ()
  else
    begin
      setCurrentGen g;
      Canvas.delete canvas [`Tag "pixels"] ;
      let cells = !computedCellsFunc g in
        List.iter (fun ((x,y),v) -> unit (paintCell x y v))
                  cells
    end


(* ----------------------------------------------------------------- *)
(* Starting display *)

let rec initializeStartDisplay () =
  begin
  let top = openTk ()
  and xdimVar = Textvariable.create ()
  and ydimVar = Textvariable.create ()
  and gensVar = Textvariable.create ()
  in
    viewVariable := Some (Textvariable.create ());
    Textvariable.set xdimVar "5";
    Textvariable.set ydimVar "5";
    Textvariable.set gensVar "5";
    let doNext () = 
      let xdim = int_of_string (Textvariable.get xdimVar)
      and ydim = int_of_string (Textvariable.get ydimVar)
      and gens = int_of_string (Textvariable.get gensVar)
      in
         destroy top;
         initializeInitialPosition gens xdim ydim

    and buttonCallback textvar increment () =
      let newvalue = (int_of_string(Textvariable.get textvar)+increment)
      in
        if newvalue>0 then
          Textvariable.set textvar (string_of_int newvalue)
        else
          ()
    in
      begin
        let xdimframe = Frame.create top 
        and ydimframe = Frame.create top 
        and genframe = Frame.create top 
        in
          pack ~side:`Top ~fill:`X [xdimframe;ydimframe;genframe];
          pack ~side:`Left ~fill:`X ~expand:true
	    [Label.create ~text:"Board width:" xdimframe ;
            Label.create ~text:"Board height:" ydimframe ;
            Label.create ~text:"generations:" genframe ];
          pack ~side:`Left [
	    coe (Label.create ~textvariable:xdimVar 
	      xdimframe);
            coe (Button.create ~text:"-" ~command:(buttonCallback xdimVar (-1))
	      xdimframe) ;
            coe (Button.create ~text:"+" ~command:(buttonCallback xdimVar 1)
	      xdimframe) ;
            coe (Label.create ~textvariable:ydimVar 
	      ydimframe) ;
            coe (Button.create ~text:"-" ~command:(buttonCallback ydimVar (-1))
	      ydimframe) ;
            coe (Button.create ~text:"+" ~command:(buttonCallback ydimVar 1)
	      ydimframe) ;
            coe (Label.create ~textvariable:gensVar genframe) ;
            coe (Button.create ~text:"-" ~command:(buttonCallback gensVar (-1))
	      genframe) ;
            coe (Button.create ~text:"+" ~command:(buttonCallback gensVar 1)
	      genframe)
	  ];
          pack ~side:`Top ~expand:false 
	    [Button.create ~text:"Enter Grid" ~command:doNext top] 

   end
end

(* ----------------------------------------------------------- *)
(* display to get initial configuration *)
and initializeInitialPosition gens xdim ydim =
  let top = openTk ()
  and valueArray = Array.create_matrix xdim ydim false
  in
  let doMain () =
    let b (x,y) = valueArray.(x).(y)
    in
         destroy top;
         initializeMainDisplay gens xdim ydim;
         !startFunc xdim ydim b gens
  and grid = Canvas.create 
    ~height:(cellSize*ydim)
    ~width:(cellSize*xdim)
    ~background:(cellstate2color Bottom)
    top 
  in
  let pixelfunc x y pixel =
    valueArray.(x).(y) <- not valueArray.(x).(y);
    Canvas.configure_rectangle 
      ~fill:(mapbool2color valueArray.(x).(y)) grid pixel 
      
  in
      pack ~side:`Top [
	coe (Label.create ~text:"Enter Initial Grid" top);
        coe grid;
        coe (Button.create ~text:"Start" ~command:doMain top)
      ];
      for x = 0 to xdim-1 do
        for y = 0 to ydim-1 do
          begin
            let pixel = 
	      Canvas.create_rectangle 
              ~x1:(cellSize*x)
              ~y1:(cellSize*y)
              ~x2:(cellSize*x+cellSize-1)
              ~y2:(cellSize*y+cellSize-1)
              ~fill:(mapbool2color valueArray.(x).(y))
              ~width:0
	      grid
	    in
	    Canvas.bind ~events:[(*([Button1],*)`ButtonRelease] 
              ~action:(fun _ -> pixelfunc x y pixel) grid pixel
          end
        done
      done
    
(* ----------------------------------------------------------------- *)
(* Main display *)

and initializeMainDisplay gens xSize ySize =
  let top = openTk () in
  let gridframe = Frame.create top 
  and viewframe = Frame.create top 
  and showngen = Textvariable.create ()
  in
    Textvariable.set showngen "0";
    let generationLabel = Label.create ~text:"Generation displayed: " gridframe 
    and generationDisplay = Label.create ~textvariable:showngen gridframe
    and grid = Canvas.create 
      ~height:(cellSize*ySize)
      ~width:(cellSize*xSize)
      ~background:(cellstate2color Bottom)
      gridframe 
    and generationCountFrame = Frame.create ~borderwidth:3 ~relief:`Groove top 
    and viewCountLabel = Label.create ~text:"Number of endpoints: " viewframe 
    and viewCountDisplay = Label.create ~textvariable:(getViewVariable ()) 
      viewframe 
    in
    pack ~side:`Bottom 
      [Button.create ~text:"Quit" ~command:(fun () -> closeTk ()) top];
    pack ~side:`Bottom [generationCountFrame; viewframe; gridframe] ;
    pack ~side:`Left [viewCountLabel; viewCountDisplay] ;
    pack ~side:`Bottom [grid];
    pack ~side:`Left [generationLabel;generationDisplay];
    let genCounters = initializeGenCounters gens generationCountFrame
                                           (function g -> function () ->
                                              displayGeneration grid g
                                           ) showngen
    in
      state := MainDisplay(grid,genCounters,0,generationDisplay,generationDisplay)

let init () = initializeStartDisplay ()

let newCellValue gen (x,y) state =
   setGenerationMsg gen (string_of_int (!numberCellsComputedCallback gen));
   if (currentGen () = gen) then
     begin
      unit (paintCell x y state)
     end
   else
      ();
    ()

let viewCount cnt = Textvariable.set (getViewVariable ()) (string_of_int cnt)
