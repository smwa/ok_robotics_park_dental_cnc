from gpiozero import Button, LED
from signal import pause

servo = Button("BOARD12", pull_up=True)
start = Button("BOARD5", pull_up=True)
pauseButton = Button("BOARD13", pull_up=True)
ESD = Button("BOARD16", pull_up=True)
chiller = Button("BOARD33", pull_up=True)
cover = Button("BOARD32", pull_up=True)
door = Button("BOARD18", pull_up=True)
blower = Button("BOARD10", pull_up=True)
stop = Button("BOARD15", pull_up=True)

startLed = LED("BOARD29")
pauseLed = LED("BOARD31")
stopLed = LED("BOARD37")
esdLed = LED("BOARD22")

def higen(name):
    def press():
        print("{} is pressed".format(name))
    return press

def logen(name):
    def release():
        print("{} is released".format(name))
    return release

blower.when_pressed = higen("Blower")
blower.when_released = logen("Blower")

door.when_pressed = higen("Door")
door.when_released = logen("Door")

cover.when_pressed = higen("Cover")
cover.when_released = logen("Cover")

chiller.when_pressed = higen("Chiller")
chiller.when_released = logen("Chiller")

servo.when_pressed = higen("Servo")
servo.when_released = logen("Servo")

ESD.when_pressed = higen("ESD")
ESD.when_released = logen("ESD")

start.when_pressed = higen("Start")
start.when_released = logen("Start")

pauseButton.when_pressed = higen("Pause")
pauseButton.when_released = logen("Pause")

stop.when_pressed = higen("Stop")
stop.when_released = logen("Stop")


startLed.blink()
pauseLed.blink()
stopLed.blink()
esdLed.blink()

pause()
