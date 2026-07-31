--!strict
-- WheelPhysics.spec.luau — pins the wheel input's feel model (Constants.WHEEL, ported from
-- prototypes/ring-feel.html). The tests worth having: neutral is the default (invariant 2), the
-- televised state is always a discrete notch (invariant 4), a release always settles exactly onto
-- a notch, a lift-off below the flick gate snaps back rather than drifting, and a flick actually
-- rolls over notches before the spring catches it.

local kit = require("./lib/testkit")
local roblox = require("./lib/robloxenv")

local Constants = roblox.requireShared("Constants")
local WheelPhysics = roblox.requireShared("WheelPhysics")

local W = Constants.WHEEL

-- Run free physics at a fixed 60 Hz until the needle lands (theta exactly integral, omega zero),
-- with a frame budget so a diverging tune fails loudly instead of hanging.
local function settle(wheel): number
	for frame = 1, 1200 do
		wheel:step(1 / 60)
		if wheel.omega == 0 and wheel.theta == math.round(wheel.theta) then
			return frame
		end
	end
	error("wheel did not settle within 1200 frames (omega=" .. wheel.omega .. ", theta=" .. wheel.theta .. ")")
end

kit.describe("WheelPhysics — neutral default and engagement", function()
	kit.it("starts neutral, televising no notch", function()
		local wheel = WheelPhysics.new()
		kit.expectEqual(wheel.neutral, true)
		kit.expectEqual(wheel:notchIndex(), nil)
		kit.expectEqual(wheel:direction(), Constants.DIRECTIONS.NEUTRAL)
	end)

	kit.it("beginDrag engages at the pointer's notch, leaving neutral", function()
		local wheel = WheelPhysics.new()
		wheel:beginDrag(2.3, 0)
		kit.expectEqual(wheel.neutral, false)
		kit.expectNear(wheel.theta, 2.3)
	end)

	kit.it("setNeutral returns to the default state", function()
		local wheel = WheelPhysics.new()
		wheel:beginDrag(3, 0)
		wheel:endDrag()
		wheel:setNeutral()
		kit.expectEqual(wheel:direction(), Constants.DIRECTIONS.NEUTRAL)
		kit.expectEqual(wheel.omega, 0)
	end)
end)

kit.describe("WheelPhysics — detent while dragging", function()
	kit.it("biases the displayed angle toward the nearest notch by DETENT", function()
		local wheel = WheelPhysics.new()
		wheel:beginDrag(2.3, 0)
		kit.expectNear(wheel:displayTheta(), 2.3 + (2 - 2.3) * W.DETENT, 1e-9)
	end)

	kit.it("televises the discrete notch, never the fraction", function()
		local wheel = WheelPhysics.new()
		wheel:beginDrag(2.3, 0)
		kit.expectEqual(wheel:notchIndex(), 2)
		kit.expectEqual(wheel:direction(), Constants.CYCLE[3])
	end)
end)

kit.describe("WheelPhysics — release settles onto a notch", function()
	kit.it("a plain lift-off (no flick) snaps back to the nearest notch exactly", function()
		local wheel = WheelPhysics.new()
		wheel:beginDrag(2.3, 0)
		wheel:endDrag()
		kit.expectEqual(wheel.omega, 0, "below-gate release must not drift")
		settle(wheel)
		kit.expectEqual(wheel.theta, 2)
		kit.expectEqual(wheel:direction(), Constants.CYCLE[3])
	end)

	kit.it("a slow release stays below the flick gate", function()
		local wheel = WheelPhysics.new()
		wheel:beginDrag(1, 0)
		-- creep: well under FLICK_MIN notches/second
		wheel:drag(1.01, 0.05)
		wheel:drag(1.02, 0.10)
		wheel:endDrag()
		kit.expectEqual(wheel.omega, 0)
	end)

	kit.it("a flick spins over at least one notch, then beds into one exactly", function()
		local wheel = WheelPhysics.new()
		wheel:beginDrag(0, 0)
		-- fast sweep: ~10 notches/second across the flick window
		wheel:drag(0.2, 0.02)
		wheel:drag(0.4, 0.04)
		wheel:drag(0.6, 0.06)
		wheel:endDrag()
		kit.expectEqual(wheel.omega > W.FLICK_MIN, true, "this release should register as a flick")
		settle(wheel)
		kit.expectEqual(wheel.theta, math.round(wheel.theta))
		kit.expectEqual(wheel.theta >= 1, true, "a flick should carry past the engaged notch")
	end)
end)

kit.describe("WheelPhysics — the televised notch wraps the cycle", function()
	kit.it("negative winding maps onto the cycle", function()
		local wheel = WheelPhysics.new()
		wheel:beginDrag(0, 0)
		wheel:endDrag()
		wheel.theta = -1
		kit.expectEqual(wheel:notchIndex(), 7)
		kit.expectEqual(wheel:direction(), Constants.CYCLE[8])
	end)

	kit.it("multi-turn winding maps onto the cycle", function()
		local wheel = WheelPhysics.new()
		wheel:beginDrag(0, 0)
		wheel:endDrag()
		wheel.theta = 8 + 3
		kit.expectEqual(wheel:notchIndex(), 3)
		kit.expectEqual(wheel:direction(), Constants.CYCLE[4])
	end)
end)
