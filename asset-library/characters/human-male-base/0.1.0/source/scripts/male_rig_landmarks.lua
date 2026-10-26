-- Male v01: independently placed joints on the 256x256 source canvas.
-- Endpoints represent bone lengths, not merely the joint overlay drawing.
return {
 {name='hips',parent='',at={120,120},tip={119,97},label='骨盆'},
 {name='torso',parent='hips',at={119,97},tip={122,44},label='腰'},
 {name='head',parent='torso',at={122,44},tip={120,23},label='頸'},
 {name='far_upper_arm',parent='torso',at={100,55},tip={95,89},label='遠肩'},
 {name='far_forearm',parent='far_upper_arm',at={95,89},tip={87,121},label='遠肘'},
 {name='far_hand',parent='far_forearm',at={87,121},tip={87,136},label='遠腕'},
 {name='near_upper_arm',parent='torso',at={148,55},tip={160,84},label='近肩'},
 {name='near_forearm',parent='near_upper_arm',at={160,84},tip={146,106},label='近肘'},
 {name='hand',parent='near_forearm',at={146,106},tip={136,110},label='近腕'},
 {name='far_thigh',parent='hips',at={106,125},tip={108,167},label='遠髖'},
 {name='far_shin',parent='far_thigh',at={108,167},tip={105,218},label='遠膝'},
 {name='far_foot',parent='far_shin',at={105,218},tip={87,230},label='遠踝'},
 {name='near_thigh',parent='hips',at={130,125},tip={138,168},label='近髖'},
 {name='near_shin',parent='near_thigh',at={138,168},tip={149,222},label='近膝'},
 {name='near_foot',parent='near_shin',at={149,222},tip={145,238},label='近踝'},
}
