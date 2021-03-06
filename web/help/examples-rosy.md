This is a collection of examples that demonstrate the capabilities of
Rosy.

Example: Move forward
================

This example makes a robot move forward at a constant velocity of 0.5 m/s.

~~~~~ . clickable
move :: Velocity
move = Velocity 0.5 0

main = simulate move
~~~~~

Example: Accelerate forward
================

This example makes a robot accelerate forward with non-constant velocity.

~~~~~ . clickable
accelerate :: Velocity -> Velocity
accelerate (Velocity vl va) = Velocity (vl+0.5) va

main = simulate accelerate
~~~~~

Example: Accelerate forward and play a sound on collision
================

This example makes a robot accelerate forward with non-constant velocity, and play a sound when it hits a wall.

~~~~~ . clickable
accelerate :: Velocity -> Velocity
accelerate (Velocity vl va) = Velocity (vl+0.5) va

play :: Bumper -> Maybe Sound
play (Bumper _ Pressed)  = Just ErrorSound
play (Bumper _ Released) = Nothing

accelerateAndPlay = (accelerate,play)

main = simulate accelerateAndPlay
~~~~~

Example: Accelerate forward and backwards
================

This example makes a robot accelerate forward, and reverse its direction when it hits a wall.

~~~~~ . clickable
type Hit = Bool

reverseDir :: Bumper -> Memory Hit
reverseDir _ = Memory True

accelerate :: Memory Hit -> Velocity -> Velocity
accelerate (Memory hit) (Velocity vl va) = if hit
    then Velocity (vl-0.5) va
    else Velocity (vl+0.5) va
    
forwardBackward = (reverseDir,accelerate)

main = simulate forwardBackward
~~~~~

Example: Blinking led
================

This example demonstrates how you can give your robot memory, and how to use that to make a led blink, alternating between two colors.

~~~~~ . clickable
data Blink = Off | On

blink :: Memory Blink -> (Led1,Memory Blink)
blink (Memory Off) = (Led1 Black,Memory On)
blink (Memory On) = (Led1 Red,Memory Off)

main = simulate blink
~~~~~

Example: Simple Random Walker
=====================

This example demonstrates how to implement a simple random walker, that makes your robot walk forward, and change course when it finds an obstacle.

~~~~~ . clickable
data Mode = Ok | Panic Clock

-- | the controller is in panic mode during 1 second since the last emergency
mode :: Memory Mode -> Clock -> Memory Mode
mode (Memory (Panic old)) new = if seconds new-seconds old > 1 then Memory Ok else Memory (Panic old)
mode (Memory Ok) _ = Memory Ok 

-- | when the robot has a serious event, signal an emergency
emergency :: Either Bumper Cliff -> Clock -> Memory Mode
emergency _ now = Memory (Panic now)

-- | move the robot depending on the mode
walk :: Orientation -> Memory Mode -> Velocity
walk (Orientation o) (Memory Ok) = Velocity 0.5 0
walk (Orientation o) (Memory (Panic _)) = Velocity 0 (pi/8)

randomWalk = (emergency,mode,walk)

main = simulate randomWalk
~~~~~

Example: Kobuki Random Walker
=====================

This example demonstrates how to replicate a Kobuki random walker, with blinking leds and randomized behavior.

~~~~~ . clickable
data Mode = Go | Stop | Turn Double Seconds
data ChgDir = ChgDir -- change direction

bumper :: Bumper -> (Led1,Maybe ChgDir)
bumper (Bumper _ st) = case st of
  Pressed -> (Led1 Orange,Just ChgDir)
  Released -> (Led1 Black,Nothing)

cliff :: Cliff -> (Led2,Maybe ChgDir)
cliff (Cliff _ st) = case st of
  Hole -> (Led2 Orange,Just ChgDir)
  Floor -> (Led2 Black,Nothing)

wheel :: Wheel -> (Led1,Led2,Memory Mode)
wheel (Wheel _ st) = case st of
  Air -> (Led1 Red,Led2 Red,Memory Stop)
  Ground -> (Led1 Black,Led2 Black,Memory Go)

chgdir :: ChgDir -> StdGen -> Seconds -> Memory Mode
chgdir _ r now = Memory (Turn dir time)
    where
    (b,r') = random r
    (ang,_) = randomR (0,pi) r'
    dir = if b then 1 else -1
    time = now + doubleToSeconds (ang / 0.1)

spin :: Memory Mode -> Seconds -> (Velocity,Memory Mode)
spin m@(Memory Stop) _ = (Velocity 0 0,m)
spin m@(Memory (Turn dir t)) now | t > now = (Velocity 0 (dir*0.1),m)
spin m _ = (Velocity 0.5 0,Memory Go)

randomWalk = (bumper,cliff,wheel,chgdir,spin)

main = simulate randomWalk
~~~~~

Example: Kobuki Random Walker with Safety Controller
=====================

This example demonstrates how to encode a multiplexer, in order to combine the Kobuki random walker and the Kobuki safety controller.

~~~~~ . clickable
-- random walker

data Mode = Go | Stop | Turn Double Seconds
data ChgDir = ChgDir -- change direction

bumper :: Bumper -> (Led1,Maybe ChgDir)
bumper (Bumper _ st) = case st of
  Pressed -> (Led1 Orange,Just ChgDir)
  Released -> (Led1 Black,Nothing)

cliff :: Cliff -> (Led2,Maybe ChgDir)
cliff (Cliff _ st) = case st of
  Hole -> (Led2 Orange,Just ChgDir)
  Floor -> (Led2 Black,Nothing)

wheel :: Wheel -> (Led1,Led2,Memory Mode)
wheel (Wheel _ st) = case st of
  Air -> (Led1 Red,Led2 Red,Memory Stop)
  Ground -> (Led1 Black,Led2 Black,Memory Go)

chgdir :: ChgDir -> StdGen -> Seconds
       -> Memory Mode
chgdir _ r now = Memory (Turn dir time)
    where
    (b,r') = random r
    (ang,_) = randomR (0,pi) r'
    dir = if b then 1 else -1
    time = now + doubleToSeconds (ang / 0.1)

spin :: Memory Mode -> Seconds -> (M2 Velocity,Memory Mode)
spin m@(Memory Stop) _ = (M2 (Velocity 0 0),m)
spin m@(Memory (Turn dir t)) now | t > now = (M2 (Velocity 0 (dir*0.1)),m)
spin m _ = (M2 (Velocity 0.5 0),Memory Go)

randomWalk = (bumper,cliff,wheel,chgdir,spin)

-- safety controller

safetyControl :: Either (Either Bumper Cliff) Wheel -> Maybe (M1 Velocity)
safetyControl (Right (Wheel _ Air)) = Just $ M1 $ Velocity 0 0
safetyControl (Left (Left (Bumper CenterBumper Pressed))) = Just $ M1 $ Velocity (-0.1) 0
safetyControl (Left (Right (Cliff CenterCliff Hole))) = Just $ M1 $ Velocity (-0.1) 0
safetyControl (Left (Left (Bumper LeftBumper Pressed))) = Just $ M1 $ Velocity (-0.1) (-0.4)
safetyControl (Left (Right (Cliff LeftCliff Hole))) = Just $ M1 $ Velocity (-0.1) (-0.4)
safetyControl (Left (Left (Bumper RightBumper Pressed))) = Just $ M1 $ Velocity (-0.1) 0.4
safetyControl (Left (Right (Cliff RightCliff Hole))) = Just $ M1 $ Velocity (-0.1) 0.4
safetyControl _ = Nothing

-- multiplexer

data M = Start | Ignore Seconds
data M1 a = M1 a
data M2 b = M2 b

timeout = 0.5

muxVel :: Seconds -> Memory M
    -> Either (M1 Velocity) (M2 Velocity) -> Maybe (Velocity,Memory M)
muxVel t _ (Left (M1 a)) = Just (a,Memory (Ignore (t+timeout)))
muxVel t (Memory (Ignore s)) (Right (M2 a)) | s > t = Nothing
muxVel t _ (Right (M2 a)) = Just (a,Memory Start)

-- safe random walker
    
safeRandomWalk = (randomWalk,safetyControl,muxVel)

main = simulate safeRandomWalk
~~~~~

Example: Task - Turn left or right by a number of degrees
=====================

This example demonstrates how to implement a simple task that makes the robot rotate to the left or to the right.

~~~~~ . clickable
type Side = Either Degrees Degrees

turn :: Side -> Task ()
turn s = task (startTurn s) runTurn

startTurn :: Side -> Orientation -> Memory Orientation
startTurn (Left a)  o = Memory (o+degreesToOrientation a)
startTurn (Right a) o = Memory (o-degreesToOrientation a)

errTurn = 0.01

runTurn :: Memory Orientation -> Orientation
        -> Either (Velocity) (Done ())
runTurn (Memory to) from = if abs d <= errTurn
    then Right (Done ())
    else Left (Velocity 0 (orientation d))
  where d = normOrientation (to-from)
    
main = simulateTask (turn $ Left 90)
~~~~~

Example: Task - Move forward or backward for a number of centimeters
=====================

This example demonstrates how to implement a simple task that makes the robot move forward or backward.

~~~~~ . clickable
data Direction = Forward Centimeters | Backward Centimeters

move :: Direction -> Task ()
move d = task (startMove d) runMove

startMove :: Direction -> Position -> Memory Position
startMove (Forward cm) p = Memory $ vecToPosition $ extVec (positionToVec p) $ centimetersToMeters cm
startMove (Backward cm) p = Memory $ vecToPosition $ extVec (positionToVec p) $ centimetersToMeters (-cm)

errMove = 0.1

runMove :: Memory Position -> Position -> Either Velocity (Done ())
runMove (Memory to) from = if abs dist <= errMove
    then Right (Done ())
    else Left (Velocity dist 0)
  where dist = magnitudeVec (subVec (positionToVec to) (positionToVec from))

main = simulateTaskIn world2 (move $ Forward 32)
~~~~~

Example: Task - Draw a square
=====================

This example demonstrates how to make the robot draw a square with his movement.

~~~~~ . clickable
import Control.Monad

-- turn left/right

type Side = Either Degrees Degrees

turn :: Side -> Task ()
turn s = task (startTurn s) runTurn

startTurn :: Side -> Orientation -> Memory Orientation
startTurn (Left a)  o = Memory (o+degreesToOrientation a)
startTurn (Right a) o = Memory (o-degreesToOrientation a)

errTurn = 0.01

runTurn :: Memory Orientation -> Orientation -> Either (Velocity) (Done ())
runTurn (Memory to) from = if abs d <= errTurn
    then Right (Done ())
    else Left (Velocity 0 (orientation d))
  where d = normOrientation (to-from)

-- task move

data Direction = Forward Centimeters | Backward Centimeters

move :: Direction -> Task ()
move d = task (startMove d) runMove

startMove :: Direction -> Orientation -> Position -> Memory Position
startMove d (Orientation angle) p = Memory $ vecToPosition $ addVec (positionToVec p) $ scalarVec (magnitude d) angle
    where
    magnitude (Forward cm) = centimetersToMeters cm
    magnitude (Backward cm) = - centimetersToMeters cm

errMove = 0.01

runMove :: Memory Position -> Position -> Either Velocity (Done ())
runMove (Memory to) from = if abs dist <= errMove
    then Right (Done ())
    else Left (Velocity dist 0)
  where dist = magnitudeVec (subVec (positionToVec to) (positionToVec from))

mainM = simulateTaskIn world2 (move $ Forward 32)

-- draw square

drawSquare :: Task ()
drawSquare = replicateM_ 4 $ do
    move (Forward 32)
    turn (Left 90)
    
main = simulateTaskIn world2 drawSquare
~~~~~


