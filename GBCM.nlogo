globals [ actors opinions range-op all-pairs num-prim-actors num-sec-actors final-clusters final-opinions cluster-count]

turtles-own [ opinion sources targets next-opinion coeff my-cluster ]

to setup
  clear-all
  create-turtles N [
    set opinion random-float 1
;    setxy opinion 0
    set color hsb (310 * opinion) 100 100
;    set shape "dot"
  ]
  set opinions [opinion] of turtles
  set range-op ( max opinions - min opinions )
  if Actor-type = "Source" [
    set num-prim-actors (min (list s N))
    set num-sec-actors (min (list t (N - 1)))
  ]
  if Actor-type = "Target" [
    set num-prim-actors (min (list t N))
    set num-sec-actors (min (list s (N - 1)))
  ]
  if Actor-type = "Group" [
    set num-prim-actors (min (list t (N * (N - 1) / 2)))
    set all-pairs []
    foreach range N [ [who1] ->
      foreach (range (who1 + 1) N) [ [who2] ->
        set all-pairs lput (turtle-set (turtle who1) (turtle who2)) all-pairs
      ]
    ]
  ]
  reset-ticks
  if update-plots? [ setup-plot ]
end

to setup-plot
  set-current-plot "Opinion over time"
  set-plot-x-range 0 (10 * update-frequency)
  ask turtles [
    create-temporary-plot-pen word "Turtle " who
    set-plot-pen-color color
    plot-pen-up
  ]
  if update-plots? [ ask turtles [ update-plot] ]
end

to go
  ask turtles [
    set sources no-turtles
    set targets no-turtles
  ]
  ; Assign relevant sets S, T, S_j, T_i as needed by actor type
  ; Note that if-values exist only to speed up calculations when parameters are infinite
  if Actor-type = "Source" [
    set actors ifelse-value (num-prim-actors = N)
      [turtles] [n-of num-prim-actors turtles] ; Set S
    ask actors [
      set targets ifelse-value (num-sec-actors = N - 1)
        [other turtles] [n-of num-sec-actors other turtles] ; Set T_i
      set targets targets with [abs (opinion - [opinion] of myself) < d]
      ifelse (num-prim-actors = N and num-sec-actors = N - 1) [
        ; unlimited actors means sources = targets (runs much faster)
        set sources targets ; Set S_j
      ] [
        ask targets [
          set sources (turtle-set sources myself) ; Set S_j
        ]
      ]
    ]
  ]
  if Actor-type = "Target" [
    set actors ifelse-value (num-prim-actors = N)
      [turtles] [n-of num-prim-actors turtles] ; Set T
    ask actors [
      set sources n-of num-sec-actors other turtles ; Set S_j
      set sources sources with [abs (opinion - [opinion] of myself) < d]
    ]
  ]
  if Actor-type = "Group" [
    ; filter pairs based on opinion similarity
    set actors ifelse-value (num-prim-actors = length all-pairs)
      [all-pairs] [n-of num-prim-actors all-pairs] ; Set A
    set actors filter [ [pair] -> max [opinion] of pair - min [opinion] of pair < d ] actors
    foreach actors [ [this-pair] ->
      ask this-pair [
        set sources (turtle-set sources other this-pair) ; Set S_j
      ]
    ]
  ]
  if-else Synchrony = "Synchronous" [ go-sync ] [ go-async ]

  ; Update plots and plotted values
  set opinions [opinion] of turtles
  set range-op ( max opinions - min opinions )
  tick
  if update-plots? [ if (ticks mod update-frequency = 0) [ ask turtles [ update-plot ] ] ]

  if check-clusters [
    if update-plots? [ ask turtles [ update-plot ] ]
    stop
  ]
end

to go-sync
  let target-set no-turtles ; set of agents with |S_j|>0
  if-else Actor-type = "Source" [
    set target-set turtle-set [targets] of actors
  ] [
    set target-set (turtle-set actors) with [count sources > 0]
  ]
  ask target-set [
    set next-opinion ( (1 - mu) * opinion + mu * mean [opinion] of sources )
  ]
  ask target-set [
    set opinion next-opinion
;    setxy opinion 0
  ]
end

to go-async
  ask turtles with [count sources > 0] [ set coeff ((1 - mu) ^ (1 / count sources)) ] ; coeff = 1 - mu^*
  if Actor-type = "Source" [
    let sourcelist ifelse-value Bias? [
      ; sort agents in ascending order of opinion
      sort-on [opinion] actors
    ] [
      ; keep agents in random order
      [self] of actors
    ]
    foreach sourcelist [ [this-source] ->
      ask this-source [
        if count targets > 0 [ ; Set T_i
          ask targets [
            set opinion coeff * opinion + (1 - coeff) * [opinion] of this-source
;            setxy opinion 0
          ]
        ]
      ]
    ]
  ]
  if Actor-type = "Target" [
    ask actors with [ count sources > 0 ] [
      let sourcelist ifelse-value Bias? [
        ; sort agents in descending order of opinion
        reverse (sort-on [opinion] sources)
      ] [
        ; keep agents in random order
        [self] of sources
      ]
      foreach sourcelist [ [this-source] ->
        set opinion coeff * opinion + (1 - coeff) * [opinion] of this-source
;        setxy opinion 0
      ]
    ]
  ]
  if Actor-type = "Group" [
    ; if Bias, sort in ascending order by mean opinion
    if Bias? [ set actors sort-by [ [set1 set2] -> mean [opinion] of set1 < mean [opinion] of set2 ] actors ]
    foreach actors [ [this-pair] ->
      ; Synchronously update both members' opinions
      ask this-pair [
        let source-op (item 0 [opinion] of other this-pair)
        set next-opinion coeff * opinion + (1 - coeff) * source-op
      ]
      ask this-pair [
        set opinion next-opinion
;        setxy opinion 0
      ]
    ]
  ]
end

to update-plot
  set-current-plot "Opinion over time"
  set-current-plot-pen word "Turtle " who
  plot-pen-down
  plotxy ticks opinion
  plot-pen-up
end

to-report check-clusters
  ; Stop at convergence within clusters
  let cluster-width 0
  let clusters []
  ask turtles [
    let cluster turtles with [abs (opinion - [opinion] of myself) < d]
    set clusters sentence clusters cluster
    set cluster-width max list cluster-width (max [opinion] of cluster - min [opinion] of cluster)
  ]
  if cluster-width < d / 2 [
    set clusters remove-duplicates clusters
    set final-clusters length clusters
    set final-opinions sort map [ [clus] -> mean [opinion] of clus ] clusters
    set cluster-count map [ [op] -> count turtles with [abs (opinion - op) < d] ] final-opinions
    report true
  ]
  report false
end
@#$#@#$#@
GRAPHICS-WINDOW
230
10
288
44
-1
-1
25.0
1
10
1
1
1
0
1
1
1
0
1
0
0
0
0
1
ticks
30.0

SLIDER
11
63
183
96
N
N
2
1000
1000.0
2
1
agents
HORIZONTAL

SLIDER
11
104
183
137
mu
mu
0.01
0.99
0.5
0.01
1
NIL
HORIZONTAL

SLIDER
11
144
183
177
s
s
1
N
2.0
1
1
agents per turn
HORIZONTAL

SLIDER
12
185
184
218
t
t
1
N
1000.0
1
1
agents per turn
HORIZONTAL

CHOOSER
12
263
166
308
Actor-type
Actor-type
"Source" "Target" "Group"
0

CHOOSER
13
316
113
361
Synchrony
Synchrony
"Synchronous" "Asynchronous"
0

BUTTON
11
7
75
40
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
82
8
145
41
Step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

BUTTON
153
9
216
42
Go
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
219
86
578
369
Results
Tick
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"mean-opinion" 1.0 0 -16777216 true "" "plot mean [opinion] of turtles"
"range-opinion" 1.0 0 -7500403 true "" "plot range-op"

SLIDER
13
224
185
257
d
d
0
1
0.2
0.01
1
NIL
HORIZONTAL

SWITCH
299
11
431
44
update-plots?
update-plots?
0
1
-1000

PLOT
12
384
576
678
Opinion over Time
tick
opinion
0.0
10.0
0.0
1.0
true
false
"" ""
PENS

SLIDER
447
14
619
47
update-frequency
update-frequency
1
1000
1.0
1
1
NIL
HORIZONTAL

TEXTBOX
301
51
612
69
Above options are for lower plot - fast updates are very slow.
11
0.0
1

MONITOR
586
386
636
431
Result
final-clusters
0
1
11

SWITCH
120
321
210
354
bias?
bias?
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

The Generalized Bounded Confidence Model (GBCM) is a generalization of the bounded confidence opinion dynamics models proposed by Deffuant et al. (2000) and Hegselmann & Krause (2002) to allow modification of the agent schedule. Schedule is specified using the SAS taxonomy.

## HOW IT WORKS

Agents are first randomly paired according to the specified schedule. Any pairings for which the difference in agent opinions is greater than d are then filtered out. Then, according to the schedule, all pairs exert influence. Specific equations are included in the associated article.

## HOW TO USE IT

Set N - the number of agents in the model.
Set mu - the convergence parameter to a value in the open set (0,1).
Set s - the number of primary actors chosen (if agent type is source), the number of secondary actors chosen (if agent type is target), or the size of groups (if agent type is group). Note: in the current version, groups are assumed to be of size 2 regardless of this setting.
Set t - the number of secondary actors chosen (if agent type is source), the number of primary actors chosen (if agent type is target), or the number of groups.
Set d - the bounded confidence parameter.
Set Actor-type - primary actor type, in accordance with the SAS taxonomy (source, target, or group)
Set Synchrony - synchronous or asynchronous, in accordance with the SAS taxonomy
Set bias? - On (agent actions are ordered to bias opinions toward 0) or Off (agent actions are in random order)
Set update-plots? - On to plot the opinion trajectory of each agent. Off otherwise.
Set update-frequency - If update-plots? is On, specifies how many time steps elapse between updates of the opinion trajectory plot. Lower values update more frequently but may slow down model runs.
Click Setup to initialize model.
Click Step to run model for a single time step.
Click Go to run model until clusters have converged to within a width of d/2.

## THINGS TO OBSERVE

The Results plot shows the mean opinion over time and the range in opinions over time.
The Opinion over Time plot shows the opinion trajectory of each agent color-coded to their initial opinions.
The Result monitor on the right displays the number of observed clusters once they have converged to within a width of d/2.

## REPLICATING RESULTS

Results from the associated paper may be replicated by using the BehaviorSpace tool (in the top menu, under Tools). AsyncS2d20 runs the Asynchronous Target/Source/Group (2,1000) results. SyncS2d20 runs the Synchronous Target/Source/Group (2,1000) results. AsyncSinftyd20 runs the Asynchronous Target/Source (infinity,1000) results. SyncSinftyd20 runs the Synchronous Target (infinity,1000) results, which is equivalent to Synchronous Source (infinity,1000).

Note: these results will take significant time to complete. It also may crash if you have not increased the amount of RAM available to NetLogo. For details on how to do this, see the section "How big can my model be? How many turtles, patches, procedures, buttons, and so on can my model contain?" in the NetLogo User Manual's FAQ. In our experimentation, no individual run used more than 4GB of RAM, although this is multiplied by the number of parallel iterations being run in BehaviorSpace.

## DISCLAIMER

The views expressed herein are those of the authors and do not reflect the official policy of position of the United States Air Force, the United States Department of Defense, or the United States Government. This material is declared a work of the U.S. Government and is not subject to copyright protection in the United States.

## REFERENCES

- Deffuant, G., Neau, D., Amblard, F. & Weisbuch, G. (2000). Mixing beliefs among interacting agents. Advances in Complex Systems, 3(1-4), 87–98. doi:10.1142/S0219525900000078. http://dx.doi.org/10.1142/S0219525900000078
- Hegselmann, R. & Krause, U. (2002). Opinion dynamics and bounded confidence: Models, analysis and simulation. Journal of Artificial Societies and Social Simulation, 5(3), 2. http://jasss.soc.surrey.ac.uk/5/3/2.html
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="AsyncS2d20" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>final-clusters</metric>
    <metric>final-opinions</metric>
    <metric>cluster-count</metric>
    <metric>mean [opinion] of turtles</metric>
    <steppedValueSet variable="mu" first="0.01" step="0.01" last="0.99"/>
    <enumeratedValueSet variable="N">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Synchrony">
      <value value="&quot;Asynchronous&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Actor-type">
      <value value="&quot;Target&quot;"/>
      <value value="&quot;Source&quot;"/>
      <value value="&quot;Group&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="s">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="t">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bias?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-plots?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SyncS2d20" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>final-clusters</metric>
    <metric>final-opinions</metric>
    <metric>cluster-count</metric>
    <metric>mean [opinion] of turtles</metric>
    <steppedValueSet variable="mu" first="0.01" step="0.01" last="0.99"/>
    <enumeratedValueSet variable="N">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Synchrony">
      <value value="&quot;Synchronous&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Actor-type">
      <value value="&quot;Target&quot;"/>
      <value value="&quot;Source&quot;"/>
      <value value="&quot;Group&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="s">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="t">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bias?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-plots?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="AsyncSinftyd20" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>final-clusters</metric>
    <metric>final-opinions</metric>
    <metric>cluster-count</metric>
    <metric>mean [opinion] of turtles</metric>
    <steppedValueSet variable="mu" first="0.01" step="0.01" last="0.99"/>
    <enumeratedValueSet variable="N">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Synchrony">
      <value value="&quot;Asynchronous&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Actor-type">
      <value value="&quot;Target&quot;"/>
      <value value="&quot;Source&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="s">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="t">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bias?">
      <value value="false"/>
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-plots?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="SyncSinftyd20" repetitions="1000" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <metric>final-clusters</metric>
    <metric>final-opinions</metric>
    <metric>cluster-count</metric>
    <metric>mean [opinion] of turtles</metric>
    <steppedValueSet variable="mu" first="0.01" step="0.01" last="0.99"/>
    <enumeratedValueSet variable="N">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Synchrony">
      <value value="&quot;Synchronous&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Actor-type">
      <value value="&quot;Target&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="s">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="t">
      <value value="1000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bias?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="d">
      <value value="0.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-frequency">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="update-plots?">
      <value value="false"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
