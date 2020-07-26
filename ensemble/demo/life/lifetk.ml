(**************************************************************)
(*
 *  Ensemble, 1.10
 *  Copyright 2001 Cornell University, Hebrew University
 *  All rights reserved.
 *
 *  See ensemble/doc/license.txt for further information.
 *)
(**************************************************************)
open Rules
open Msgs
open Tk

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
                  | MainDisplay of (Widget.widget *   (* the canvas display *)
                              Widget.widget list * (* list of gen counters *)
                              int *  (* generation being displayed *)
                              Widget.widget * (* label showing generation # *)
                              Widget.widget)  (* label showing endpoints *)

let state = ref Starting

(* maps cell states to the colors that they will be displayed as *)

let cellColors = [(Bottom, NamedColor "grey");
                  (Live, NamedColor "blue");
                  (Dead, Black)]

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
   Canvas.create_rectangle (boardcanvas ()) 
       (Pixels (cellSize*x)) (Pixels (cellSize*y))
       (Pixels (cellSize*x+cellSize-1)) (Pixels (cellSize*y+cellSize-1))
       [FillColor (cellstate2color c);
       Width (Pixels 0);
       Tags [(Tag "pixels")]]

let setGenerationMsg g m =
    Label.configure (List.nth (gencounters ()) g)
                    [Text m]

let initializeGenCounters maxgen parent pressfunc genvariable =
  let rec range i limit = if i == limit then
                          [i]
                       else
                          i :: (range (i+1) limit)
  in
     let titleframe = Frame.create parent []
     and genframes =   List.map (function g ->
                                    Frame.create parent 
                                                 [BorderWidth (Pixels 1);
                                                  Relief Raised ]
                                )
                       (range 0 maxgen)
     in
       pack [titleframe] [Side Side_Left];
       pack genframes [Side Side_Left];
       pack [(Label.create titleframe [Text "generation"])] [Side Side_Top];
       pack [(Label.create titleframe [Text "computed"])] [Side Side_Top];
       pack [(Label.create titleframe [Text ""])] [Side Side_Top];
       List.map (function g ->
                   let thisframe = List.nth genframes g
                   in
                      pack [(Label.create thisframe [Text (string_of_int g)])]
                           [Side Side_Top];
                      let thisCounter = Label.create thisframe [Text "0"]
                      in
                        pack [thisCounter] [Side Side_Top];
                        pack [(Radiobutton.create thisframe
                                    [Variable genvariable;
                                     Value (string_of_int g);
                                     Command (pressfunc g)])]
                             [Side Side_Top];
                        thisCounter
                 )
                 (range 0 maxgen)

let displayGeneration canvas g =
  if g = currentGen () then
    ()
  else
    begin
      setCurrentGen g;
      Canvas.delete canvas [(Tag "pixels")];
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
        let xdimframe = Frame.create top []
        and ydimframe = Frame.create top []
        and genframe = Frame.create top []
        in
          pack [xdimframe;ydimframe;genframe] [Side Side_Top; Fill Fill_X];
          pack [Label.create xdimframe [Text "Board width:"];
                Label.create ydimframe [Text "Board height:"];
                Label.create genframe [Text "generations:"]]
               [Side Side_Left; Fill Fill_X; Expand true];
          pack [Label.create xdimframe [TextVariable xdimVar];
                Button.create xdimframe [Text "-";
                                         Command (buttonCallback xdimVar (-1))];
                Button.create xdimframe [Text "+";
                                         Command (buttonCallback xdimVar 1)];
                Label.create ydimframe [TextVariable ydimVar];
                Button.create ydimframe [Text "-";
                                         Command (buttonCallback ydimVar (-1))];
                Button.create ydimframe [Text "+";
                                         Command (buttonCallback ydimVar 1)];
                Label.create genframe [TextVariable gensVar];
                Button.create genframe [Text "-";
                                         Command (buttonCallback gensVar (-1))];
                Button.create genframe [Text "+";
                                         Command (buttonCallback gensVar 1)]
]
              [Side Side_Left];
           pack [(Button.create top [(Text "Enter Grid"); Command doNext])] 
                  [Side Side_Top; Expand false]
   end
end

(* ----------------------------------------------------------- *)
(* display to get initial configuration *)
and initializeInitialPosition gens xdim ydim =
  let top = openTk ()
  and valueArray = Array.create_matrix xdim ydim false
  in
  let doMain () =
    Printf.eprintf "doMain\n" ;
    let b (x,y) = valueArray.(x).(y)
    in
         destroy top;
         initializeMainDisplay gens xdim ydim;
         !startFunc xdim ydim b gens
  and grid = Canvas.create top [Height (Pixels (cellSize*ydim));
                                Width (Pixels (cellSize*xdim));
                                Background (cellstate2color Bottom)]
  in
  let pixelfunc x y pixel _ =
    valueArray.(x).(y) <- not valueArray.(x).(y);
    Canvas.configure_rectangle grid pixel 
      [FillColor (mapbool2color valueArray.(x).(y))]
  in
      pack [Label.create top [(Text "Enter Initial Grid")];
            grid;
            Button.create top [(Text "Start"); Command doMain]]
           [Side Side_Top];
      for x = 0 to xdim-1 do
        for y = 0 to ydim-1 do
          begin
            let pixel = Canvas.create_rectangle grid
                           (Pixels (cellSize*x)) 
                           (Pixels (cellSize*y))
                           (Pixels (cellSize*x+cellSize-1))
                           (Pixels (cellSize*y+cellSize-1))
                           [FillColor (mapbool2color valueArray.(x).(y));
                           Width (Pixels 0)]
            in
                Canvas.bind grid pixel [([Button1],ButtonRelease)]
                                          (BindSet ([],pixelfunc x y pixel))
          end
        done
     done

    
(* ----------------------------------------------------------------- *)
(* Main display *)

and initializeMainDisplay gens xSize ySize =
  let top = openTk () in
  let gridframe = Frame.create top []
  and viewframe = Frame.create top []
  and showngen = Textvariable.create ()
  in
    Textvariable.set showngen "0";
    let generationLabel = Label.create gridframe 
                                     [Text "Generation displayed: "]
    and generationDisplay = Label.create gridframe
                                     [TextVariable showngen]
    and grid = Canvas.create gridframe [Height (Pixels (cellSize*ySize));
                                Width (Pixels (cellSize*xSize));
                                Background (cellstate2color Bottom)]
    and generationCountFrame = Frame.create top [BorderWidth (Pixels 3);
                                                 Relief Groove]
    and viewCountLabel = Label.create viewframe [Text "Number of endpoints: "]
    and viewCountDisplay = Label.create viewframe 
                                                [TextVariable 
                                                    (getViewVariable ())]
  in
    pack [Button.create top [Text "Quit"; Command (fun () -> closeTk ())]]
         [Side Side_Bottom];
    pack [generationCountFrame; viewframe; gridframe] [Side Side_Bottom];
    pack [viewCountLabel; viewCountDisplay] [Side Side_Left];
    pack [grid] [Side Side_Bottom];
    pack [generationLabel;generationDisplay] [Side Side_Left];
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
