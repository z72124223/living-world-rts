-- Rest-pose landmarks, in the shared 256x256 pixel canvas.
-- Placed against the full-coverage anatomical calibration sprite, not armour edges.
-- Explicit endpoints set BOTH Bone2D length and display angle. Angles here do
-- not rotate the artwork; rotation keys are offsets from this authored rest pose.
return {
 {name='hips',parent='',at={121,120},tip={119,96},label='骨盆'},
 {name='torso',parent='hips',at={119,96},tip={119,54},label='腰'},
 {name='head',parent='torso',at={119,54},tip={120,28},label='頸'},
 {name='far_upper_arm',parent='torso',at={105,64},tip={97,93},label='遠肩'},
 {name='far_forearm',parent='far_upper_arm',at={97,93},tip={92,120},label='遠肘'},
 {name='far_hand',parent='far_forearm',at={92,120},tip={91,131},label='遠腕'},
 {name='near_upper_arm',parent='torso',at={139,64},tip={155,90},label='近肩'},
 {name='near_forearm',parent='near_upper_arm',at={155,90},tip={142,107},label='近肘'},
 {name='hand',parent='near_forearm',at={142,107},tip={133,112},label='近腕'},
 {name='far_thigh',parent='hips',at={107,124},tip={108,167},label='遠髖'},
 {name='far_shin',parent='far_thigh',at={108,167},tip={106,213},label='遠膝'},
 {name='far_foot',parent='far_shin',at={106,213},tip={91,224},label='遠踝'},
 {name='near_thigh',parent='hips',at={132,124},tip={139,169},label='近髖'},
 {name='near_shin',parent='near_thigh',at={139,169},tip={148,219},label='近膝'},
 {name='near_foot',parent='near_shin',at={148,219},tip={145,233},label='近踝'},
 {name='sash',parent='hips',at={125,103},tip={130,153},accessory=true},
 {name='weapon',parent='hand',at={137,111},tip={174,151},accessory=true},
}
