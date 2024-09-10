#|-------------Prologue---------------
Program Name: EECS_581_Project1_Battleship
Description:

Input: Number of Ships
Output: 800x800 Window of a Battleship Gam

Language: Racket
Library: R-Cade
Sources: Racket Documentation, R-Cade Tutorial, and ChatGPT

Collaborators: Saje Cowell, Charlie Gillund, Spencer Slilffe, and Jeff 
Date Created: 9/5/24
|#


#lang racket
(require r-cade)
(require racket/match)

;;-------------Initialization---------------;;

;; Define States
(define home 0)
(define ship-selection 1)
(define ship-placement 2)
(define in-play 3)
(define game-over 4)

;; Declare Variables
(define boardSize 10)
(define cellSize 40)
(define x-offset 200)
(define y-offset 200)
(define button-width 160)
(define button-height 60)
(define currentState home)
(define num-ships 0)
(define ships-placed 0)  ; Track number of ships placed
(define opponent-y-offset 50)  ; Opponent grid placed at the top
(define player-y-offset 465)   ; Player grid placed below
(define playerTurn 0) 

;; Track ship sizes and placements
(define ship-sizes '())
(define ships-placed-locations '())
(define ship-orientation 'horizontal)  ; Default orientation

;; Initialize the board with vectors
(define (createBoard size)
  (let ([board (make-vector size)])  ; Create an outer vector for rows
    (for ([i (in-range size)])
      (vector-set! board i (make-vector size #f)))  ; Set each element to a vector (row)
    board))


(define initialBoard (createBoard boardSize))
(define opponentBoard (createBoard boardSize))

;; Function to draw the grid for in-play
(define (draw-grid x-offset y-offset board)
  ;; Draw grid lines and filled cells
  (for ([i (in-range boardSize)])
    (for ([j (in-range boardSize)])
      ;; Draw grid lines
      (color 7)  ; Set color to white
      (rect (+ x-offset (* j cellSize))
            (+ y-offset (* i cellSize)) 
            cellSize cellSize 
            #:fill #f)  ; Draw the cell outline
      ;; If there is a ship on this cell, fill it in
      (when (vector-ref (vector-ref board i) j)
        (color 7)
        (rect (+ x-offset (* j cellSize)) 
              (+ y-offset (* i cellSize)) 
              cellSize cellSize 
              #:fill #t)))))  ; Draw the cell filled if ship present

;; Checks if the mouse click is within a given area
(define (mouse-in? mx my x y width height)
  (and (<= x mx (+ x width))
       (<= y my (+ y height))))

;; Converts mouse position to board coordinates
(define (mouse-to-board mx my)
  (let* ((col (quotient (- mx x-offset) cellSize))
         (row (quotient (- my y-offset) cellSize)))
    (if (and (>= col 0) (< col boardSize) (>= row 0) (< row boardSize))
        (cons row col)
        #f)))

(define (print-board board)
  (for ([i (in-range (vector-length board))])
    (printf "~a~n" (vector->list (vector-ref board i)))))


;; Checks if a ship can be placed without overlapping or out of bounds
(define (can-place-ship? board row col size orientation)
  (let ([result (cond
                  [(eq? orientation 'horizontal)
                   (and (<= (+ col size) boardSize) ; Ensure it fits horizontally
                        (for/and ([i (in-range size)])
                          (not (vector-ref (vector-ref board row) (+ col i))))) ; Check specific cells horizontally
                  ]
                  [(eq? orientation 'vertical)
                   (and (<= (+ row size) boardSize) ; Ensure it fits vertically
                        (for/and ([i (in-range size)])
                          (not (vector-ref (vector-ref board (+ row i)) col)))) ; Check specific cells vertically
                  ])])
    (displayln (format "Checking placement at row ~a, col ~a, size ~a, orientation ~a: ~a"
                       row col size orientation result))
    result))


;; Places a ship on the board
(define (place-ship board row col size orientation)
  (for ([i (in-range size)])
    (if (eq? orientation 'horizontal)
        (begin
          (printf "Placing horizontally at row ~a, col ~a~n" row (+ col i))
          (vector-set! (vector-ref board row) (+ col i) #t))  ; Mark horizontal cells
        (begin
          (printf "Placing vertically at row ~a, col ~a~n" (+ row i) col)
          (vector-set! (vector-ref board (+ row i)) col #t))))  ; Mark vertical cells
  ;; Add the ship's information to the ships-placed-locations
  (set! ships-placed-locations (cons (list row col size orientation) ships-placed-locations))
  (print-board board))

;; Removes the most recently added ship from the board
(define (remove-ship board ship)
  (let* ((row (first ship))
         (col (second ship))
         (size (third ship))
         (orientation (fourth ship)))
    (for ([i (in-range size)])
      (if (eq? orientation 'horizontal)
          (vector-set! (vector-ref board row) (+ col i) #f)
          (vector-set! (vector-ref board (+ row i)) col #f))))
  (set! ships-placed-locations (rest ships-placed-locations))
  (print-board board))

;;50/50 RNG to determine who starts the game first
(define (coinToss)
  (cond [(eq? (modulo (random 1 100) 2) 0)
         (set! playerTurn 1)
         (set! playerTurn 0)]))

;; Game update function
(define (update state)
  (let* ((mouseX (mouse-x))
         (mouseY (mouse-y))
         (mouseClicked (btn-mouse))
         (leftPressed (btn-left)))
    (cond
      [(and (eq? currentState home)
            (mouse-in? mouseX mouseY 340 225 button-width button-height)
            mouseClicked)
       (set! currentState ship-selection)
       (printf "Transitioning to Ship Selection State~n")]

      [(eq? currentState ship-selection)
       (for ([i (in-range 5)])
         (let ((option-y (+ 60 (* i 50))))
           (when (and (mouse-in? mouseX mouseY 350 option-y 100 40)
                      mouseClicked)
             (set! currentState ship-placement)
             (set! num-ships (+ i 1))
             (set! ship-sizes (reverse (build-list num-ships add1)))  ; Create ship sizes 1 to num-ships
             (printf "Transitioning to Ship Placement State with ~a ships~n" num-ships))))]

      [(eq? currentState ship-placement)
       ;; Toggle orientation on LEFT arrow key press
       (when (btn-left)
         (set! ship-orientation (if (eq? ship-orientation 'horizontal) 'vertical 'horizontal))
         (printf "Ship orientation changed to ~a~n" ship-orientation))

       ;; Place ships
       (when (and mouseClicked (< ships-placed num-ships))
         (let* ((board-pos (mouse-to-board mouseX mouseY))
                (current-ship-size (list-ref ship-sizes ships-placed)))
           (when (and board-pos
                      (can-place-ship? initialBoard (car board-pos) (cdr board-pos) current-ship-size ship-orientation))
             (place-ship initialBoard (car board-pos) (cdr board-pos) current-ship-size ship-orientation)
             (set! ships-placed (+ ships-placed 1))
             (printf "Placed ship of size ~a at ~a, ~a~n" current-ship-size (car board-pos) (cdr board-pos)))))

       ;; Check if all ships are placed
       (when (= ships-placed num-ships)
         ;; Start Game Button
         (when (and (mouse-in? mouseX mouseY 300 750 button-width button-height) mouseClicked)
           (set! currentState in-play)
           (printf "All ships placed, transitioning to In-Play State~n")))
       
       ;; Revert Button
       (when (and (mouse-in? mouseX mouseY 300 650 button-width button-height) mouseClicked
                  (> ships-placed 0))
         (remove-ship initialBoard (first ships-placed-locations))
         (set! ships-placed (- ships-placed 1))
         (printf "Reverted last ship placement, ~a ships remaining~n" ships-placed))])))

;; Function to approximate text centering horizontally
(define (center-text x y width text-str)
  (let* ((font-width (font-advance))
         (text-length (* (string-length text-str) font-width))
         (text-x (+ x (/ (- width text-length) 2))))
    (text text-x y text-str)))

;; Function to Draw the State
(define (draw state)
  (begin
    (cls)  ; Clear the screen
    (cond
      ;; Draw Home Menu
      [(eq? currentState home)
       (color 7)  ; Set color to white using palette index
       (rect 300 200 button-width button-height #:fill #t)
       (color 0)  ; Set color to black using palette index
       (text 340 225 "Start Game")

       ;; Set the font to a larger size
       (font wide-font)
       (color 7)
       (text 300 100 "Welcome to Battleship!")]

      ;; Draw Ship Selection Screen
      [(eq? currentState ship-selection)
       (color 0)  ; Set color to black for text
       (font tall-font)
       (text 20 20 "Select the number of ships:")
       (for ([i (in-range 5)])
         (let ((option-y (+ 60 (* i 50))))
           (color 7)  ; Set color to white for button
           (rect 350 option-y 100 40 #:fill #t)
           (color 0)  ; Set color to black for text
           ;; Correctly use center-text to draw the text
           (text 375 (+ option-y 20) (format "~a Ships" (+ i 1)))))
       (text 20 300 "Click on a number to select the number of ships.")]

      ;; Draw Ship Placement State
      [(eq? currentState ship-placement)
       (color 7)
       (font wide-font)
       (text 175 100 "Place Your Ships! Press LEFT arrow to toggle orientation.")
       ;; Draw grid
       (for ([i (in-range (+ boardSize 1))])
         ;; Vertical lines
         (line (+ x-offset (* i cellSize)) y-offset
               (+ x-offset (* i cellSize)) (+ y-offset (* boardSize cellSize)))
         ;; Horizontal lines
         (line x-offset (+ y-offset (* i cellSize))
               (+ x-offset (* boardSize cellSize)) (+ y-offset (* i cellSize))))
       ;; Draw ships on the board
       (for ([ship ships-placed-locations])
         (let* ((row (first ship))
                (col (second ship))
                (size (third ship))
                (orientation (fourth ship)))
           (for ([i (in-range size)])
             (if (eq? orientation 'horizontal)
                 (rect (+ x-offset (* col cellSize) (* i cellSize))
                       (+ y-offset (* row cellSize))
                       cellSize cellSize
                       #:fill #t)
                 (rect (+ x-offset (* col cellSize))
                       (+ y-offset (* row cellSize) (* i cellSize))
                       cellSize cellSize
                       #:fill #t)))))
       
       ;; Draw Start Game button after all ships placed
       (when (= ships-placed num-ships)
         (color 7)
         (rect 300 750 button-width button-height #:fill #t)
         (color 0)
         (center-text 300 775 button-width "Start Game"))

       ;; Draw Revert button
       (color 7)
       (rect 300 650 button-width button-height #:fill #t)
       (color 0)
       (center-text 300 675 button-width "Revert Ship")]

      ;; Draw In-Play State
      [(eq? currentState in-play)
       (font wide-font)
       ;; Draw opponent's board
       (text 330 10 "Opponent's Board")
       (draw-grid x-offset 25 opponentBoard)  ; Oppenent's board
 
       ;; Draw player's board with placed ships
       (text 355 450 "Your Board")
       (draw-grid x-offset player-y-offset initialBoard)]  ; Player's board

      ;; Draw Game Over State
      [(eq? currentState game-over)
       (font wide-font)
       (color 7)
       (text 300 100 "Game Over!")])))

;;-------------Run Game---------------;;
;; Game loop function that includes both update and draw
(define (game-loop)
  (begin
    (update currentState)
    (draw currentState)))

;; Start the game loop
(run game-loop
     800    ; width of the window
     900    ; height of the window
     #:fps 60)  ; Set the frame rate to 60 FPS