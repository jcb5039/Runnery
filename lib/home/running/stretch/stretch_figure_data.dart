// 이 파일은 디자인(30-2 스트레칭 따라 하기)의 사람 그림에서 자동으로 옮겼습니다. 직접 고치지 마세요.
// 좌표는 200×200 기준입니다. 색 이름은 stretch_figure.dart의 [FigInk]를 보세요.
part of 'stretch_figure.dart';

/// 동작 5개의 그림: 발목 돌리기, 레그 스윙, 워킹 런지, 하이 니, 버트 킥.
const stretchFigures = <FigGroup>[
  FigGroup(
    children: [
      FigShape.path('M34 196.5H166', stroke: FigInk.ground, strokeWidth: 2),
      FigGroup(
        children: [
          FigGroup(
            motion: 'st1-spin',
            children: [
              FigShape.path(
                'M115.3 192.1A15 15 0 1 1 130.3 192.1',
                stroke: FigInk.arrow,
                strokeWidth: 2.5,
              ),
              FigShape.path(
                'M137.9 193.2L130.3 192.1L133.1 184.9',
                stroke: FigInk.arrow,
                strokeWidth: 2.5,
              ),
            ],
          ),
          FigGroup(
            children: [
              FigGroup(
                children: [
                  FigGroup(
                    pose: FigPose.rotate(35.6, 100, 60),
                    children: [
                      FigShape.path(
                        'M94 60A6 6 0 0 1 106 60L104.5 90A4.5 4.5 0 0 1 95.5 90Z',
                        fill: FigInk.far,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(-96.5, 100, 90),
                        children: [
                          FigShape.path(
                            'M95.5 90A4.5 4.5 0 0 1 104.5 90L103.5 113A3.5 3.5 0 0 1 96.5 113Z',
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                          FigShape.circle(
                            100,
                            117,
                            4.6,
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                children: [
                  FigShape.path(
                    'M89 104A11 11 0 0 1 111 104C112.5 117 110 133 107 146A7 7 0 0 1 93 146C90.5 133 88 118 89 104Z',
                    fill: FigInk.far,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigGroup(
                    children: [
                      FigShape.path(
                        'M93 146A7 7 0 0 1 107 146C106 160 105 174 104 187A4 4 0 0 1 96 187C93 177 86.5 160 93 146Z',
                        fill: FigInk.far,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        children: [
                          FigShape.path(
                            'M95 184C99 182.5 103 182.5 105.5 184C109.5 185.5 113 187.5 115.5 189.5C117.2 191 116.6 193 114 193L95 193C92.2 193 91.5 190.5 92 188.5C92.5 186.2 93.5 184.6 95 184Z',
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                children: [
                  FigShape.path(
                    'M96.5 40L104.5 40L105.5 52C110 55 114 60 114.5 67C115 74 113 81 111 88C110 94 112.5 100 112 106C111.5 112 108 117 102 120L92 120C87 118 84.5 113 85 107C85.5 102 89 98 92 94C93 88 89.5 82 89 75C88.5 68 89.5 60 95.5 53Z',
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigShape.circle(
                    101,
                    30,
                    11.5,
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                ],
              ),
              FigGroup(
                pose: FigPose.rotate(-37.8, 100, 104),
                motion: 'st1-nlT',
                children: [
                  FigShape.path(
                    'M89 104A11 11 0 0 1 111 104C112.5 117 110 133 107 146A7 7 0 0 1 93 146C90.5 133 88 118 89 104Z',
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigGroup(
                    pose: FigPose.rotate(41.9, 100, 146),
                    motion: 'st1-nlS',
                    children: [
                      FigShape.path(
                        'M93 146A7 7 0 0 1 107 146C106 160 105 174 104 187A4 4 0 0 1 96 187C93 177 86.5 160 93 146Z',
                        fill: FigInk.near,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigShape.path(
                        'M94.5 150C88.5 156.5 89 169 95 179C97.5 170 98 158 94.5 150Z',
                        fill: FigInk.accent,
                      ),
                      FigShape.path(
                        'M104.5 152C106 161 105.5 171 103 180C101.5 171 101.5 161 104.5 152Z',
                        fill: FigInk.accent,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(46, 100, 188),
                        motion: 'st1-nlF',
                        children: [
                          FigShape.path(
                            'M95 184C99 182.5 103 182.5 105.5 184C109.5 185.5 113 187.5 115.5 189.5C117.2 191 116.6 193 114 193L95 193C92.2 193 91.5 190.5 92 188.5C92.5 186.2 93.5 184.6 95 184Z',
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                children: [
                  FigGroup(
                    pose: FigPose.rotate(32.2, 100, 60),
                    children: [
                      FigShape.path(
                        'M94 60A6 6 0 0 1 106 60L104.5 90A4.5 4.5 0 0 1 95.5 90Z',
                        fill: FigInk.near,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(-95.4, 100, 90),
                        children: [
                          FigShape.path(
                            'M95.5 90A4.5 4.5 0 0 1 104.5 90L103.5 113A3.5 3.5 0 0 1 96.5 113Z',
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                          FigShape.circle(
                            100,
                            117,
                            4.6,
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  FigGroup(
    children: [
      FigShape.path('M34 196.5H166', stroke: FigInk.ground, strokeWidth: 2),
      FigGroup(
        children: [
          FigGroup(
            children: [
              FigGroup(
                pose: FigPose.rotate(-3, 100, 104),
                motion: 'st2-lean',
                children: [
                  FigGroup(
                    pose: FigPose.rotate(-69, 100, 60),
                    motion: 'st2-faU',
                    children: [
                      FigShape.path(
                        'M94 60A6 6 0 0 1 106 60L104.5 90A4.5 4.5 0 0 1 95.5 90Z',
                        fill: FigInk.far,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(-4, 100, 90),
                        children: [
                          FigShape.path(
                            'M95.5 90A4.5 4.5 0 0 1 104.5 90L103.5 113A3.5 3.5 0 0 1 96.5 113Z',
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                          FigShape.circle(
                            100,
                            117,
                            4.6,
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                children: [
                  FigShape.path(
                    'M89 104A11 11 0 0 1 111 104C112.5 117 110 133 107 146A7 7 0 0 1 93 146C90.5 133 88 118 89 104Z',
                    fill: FigInk.far,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigGroup(
                    children: [
                      FigShape.path(
                        'M93 146A7 7 0 0 1 107 146C106 160 105 174 104 187A4 4 0 0 1 96 187C93 177 86.5 160 93 146Z',
                        fill: FigInk.far,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        children: [
                          FigShape.path(
                            'M95 184C99 182.5 103 182.5 105.5 184C109.5 185.5 113 187.5 115.5 189.5C117.2 191 116.6 193 114 193L95 193C92.2 193 91.5 190.5 92 188.5C92.5 186.2 93.5 184.6 95 184Z',
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                pose: FigPose.rotate(-3, 100, 104),
                motion: 'st2-lean',
                children: [
                  FigShape.path(
                    'M96.5 40L104.5 40L105.5 52C110 55 114 60 114.5 67C115 74 113 81 111 88C110 94 112.5 100 112 106C111.5 112 108 117 102 120L92 120C87 118 84.5 113 85 107C85.5 102 89 98 92 94C93 88 89.5 82 89 75C88.5 68 89.5 60 95.5 53Z',
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigShape.circle(
                    101,
                    30,
                    11.5,
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                ],
              ),
              FigGroup(
                pose: FigPose.rotate(-55, 100, 104),
                motion: 'st2-nlT',
                children: [
                  FigShape.path(
                    'M89 104A11 11 0 0 1 111 104C112.5 117 110 133 107 146A7 7 0 0 1 93 146C90.5 133 88 118 89 104Z',
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigShape.path(
                    'M95.5 109C89.5 115 89.5 131 94.5 142C97.5 131 98 119 95.5 109Z',
                    fill: FigInk.accent,
                  ),
                  FigShape.path(
                    'M103 97C108.5 99 111 104 109.5 110C106 108 103.5 103 103 97Z',
                    fill: FigInk.accent,
                  ),
                  FigGroup(
                    pose: FigPose.rotate(10, 100, 146),
                    motion: 'st2-nlS',
                    children: [
                      FigShape.path(
                        'M93 146A7 7 0 0 1 107 146C106 160 105 174 104 187A4 4 0 0 1 96 187C93 177 86.5 160 93 146Z',
                        fill: FigInk.near,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(8, 100, 188),
                        motion: 'st2-nlF',
                        children: [
                          FigShape.path(
                            'M95 184C99 182.5 103 182.5 105.5 184C109.5 185.5 113 187.5 115.5 189.5C117.2 191 116.6 193 114 193L95 193C92.2 193 91.5 190.5 92 188.5C92.5 186.2 93.5 184.6 95 184Z',
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                pose: FigPose.rotate(-3, 100, 104),
                motion: 'st2-lean',
                children: [
                  FigGroup(
                    pose: FigPose.rotate(35.2, 100, 60),
                    motion: 'st2-naU',
                    children: [
                      FigShape.path(
                        'M94 60A6 6 0 0 1 106 60L104.5 90A4.5 4.5 0 0 1 95.5 90Z',
                        fill: FigInk.near,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(-95.4, 100, 90),
                        children: [
                          FigShape.path(
                            'M95.5 90A4.5 4.5 0 0 1 104.5 90L103.5 113A3.5 3.5 0 0 1 96.5 113Z',
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                          FigShape.circle(
                            100,
                            117,
                            4.6,
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  FigGroup(
    children: [
      FigShape.path('M34 196.5H166', stroke: FigInk.ground, strokeWidth: 2),
      FigGroup(
        pose: FigPose.translate(2, 40),
        motion: 'st3-root',
        children: [
          FigGroup(
            children: [
              FigGroup(
                children: [
                  FigGroup(
                    pose: FigPose.rotate(35.6, 100, 60),
                    children: [
                      FigShape.path(
                        'M94 60A6 6 0 0 1 106 60L104.5 90A4.5 4.5 0 0 1 95.5 90Z',
                        fill: FigInk.far,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(-96.5, 100, 90),
                        children: [
                          FigShape.path(
                            'M95.5 90A4.5 4.5 0 0 1 104.5 90L103.5 113A3.5 3.5 0 0 1 96.5 113Z',
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                          FigShape.circle(
                            100,
                            117,
                            4.6,
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                pose: FigPose.rotate(0.5, 100, 104),
                motion: 'st3-flT',
                children: [
                  FigShape.path(
                    'M89 104A11 11 0 0 1 111 104C112.5 117 110 133 107 146A7 7 0 0 1 93 146C90.5 133 88 118 89 104Z',
                    fill: FigInk.far,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigGroup(
                    pose: FigPose.rotate(100.2, 100, 146),
                    motion: 'st3-flS',
                    children: [
                      FigShape.path(
                        'M93 146A7 7 0 0 1 107 146C106 160 105 174 104 187A4 4 0 0 1 96 187C93 177 86.5 160 93 146Z',
                        fill: FigInk.far,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(-36.7, 100, 188),
                        motion: 'st3-flF',
                        children: [
                          FigShape.path(
                            'M95 184C99 182.5 103 182.5 105.5 184C109.5 185.5 113 187.5 115.5 189.5C117.2 191 116.6 193 114 193L95 193C92.2 193 91.5 190.5 92 188.5C92.5 186.2 93.5 184.6 95 184Z',
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                children: [
                  FigShape.path(
                    'M96.5 40L104.5 40L105.5 52C110 55 114 60 114.5 67C115 74 113 81 111 88C110 94 112.5 100 112 106C111.5 112 108 117 102 120L92 120C87 118 84.5 113 85 107C85.5 102 89 98 92 94C93 88 89.5 82 89 75C88.5 68 89.5 60 95.5 53Z',
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigShape.path(
                    'M94 99C88 101.5 86.5 111 91.5 116.5C97 114 98.5 105 94 99Z',
                    fill: FigInk.accent,
                  ),
                  FigShape.circle(
                    101,
                    30,
                    11.5,
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                ],
              ),
              FigGroup(
                pose: FigPose.rotate(-85.7, 100, 104),
                motion: 'st3-nlT',
                children: [
                  FigShape.path(
                    'M89 104A11 11 0 0 1 111 104C112.5 117 110 133 107 146A7 7 0 0 1 93 146C90.5 133 88 118 89 104Z',
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigShape.path(
                    'M104 108C110.5 113 111 130 105.5 141C103 131 101.5 118 104 108Z',
                    fill: FigInk.accent,
                  ),
                  FigGroup(
                    pose: FigPose.rotate(99.3, 100, 146),
                    motion: 'st3-nlS',
                    children: [
                      FigShape.path(
                        'M93 146A7 7 0 0 1 107 146C106 160 105 174 104 187A4 4 0 0 1 96 187C93 177 86.5 160 93 146Z',
                        fill: FigInk.near,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(-13.6, 100, 188),
                        motion: 'st3-nlF',
                        children: [
                          FigShape.path(
                            'M95 184C99 182.5 103 182.5 105.5 184C109.5 185.5 113 187.5 115.5 189.5C117.2 191 116.6 193 114 193L95 193C92.2 193 91.5 190.5 92 188.5C92.5 186.2 93.5 184.6 95 184Z',
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                children: [
                  FigGroup(
                    pose: FigPose.rotate(32.2, 100, 60),
                    children: [
                      FigShape.path(
                        'M94 60A6 6 0 0 1 106 60L104.5 90A4.5 4.5 0 0 1 95.5 90Z',
                        fill: FigInk.near,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(-95.4, 100, 90),
                        children: [
                          FigShape.path(
                            'M95.5 90A4.5 4.5 0 0 1 104.5 90L103.5 113A3.5 3.5 0 0 1 96.5 113Z',
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                          FigShape.circle(
                            100,
                            117,
                            4.6,
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  FigGroup(
    children: [
      FigShape.path('M34 196.5H166', stroke: FigInk.ground, strokeWidth: 2),
      FigGroup(
        pose: FigPose.translate(0, -2),
        motion: 'st4-root',
        children: [
          FigGroup(
            children: [
              FigGroup(
                pose: FigPose.rotate(2, 100, 104),
                children: [
                  FigGroup(
                    pose: FigPose.rotate(-40, 100, 60),
                    motion: 'st4-faU',
                    children: [
                      FigShape.path(
                        'M94 60A6 6 0 0 1 106 60L104.5 90A4.5 4.5 0 0 1 95.5 90Z',
                        fill: FigInk.far,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(-88, 100, 90),
                        children: [
                          FigShape.path(
                            'M95.5 90A4.5 4.5 0 0 1 104.5 90L103.5 113A3.5 3.5 0 0 1 96.5 113Z',
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                          FigShape.circle(
                            100,
                            117,
                            4.6,
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                motion: 'st4-flT',
                children: [
                  FigShape.path(
                    'M89 104A11 11 0 0 1 111 104C112.5 117 110 133 107 146A7 7 0 0 1 93 146C90.5 133 88 118 89 104Z',
                    fill: FigInk.far,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigShape.path(
                    'M104 108C110.5 113 111 130 105.5 141C103 131 101.5 118 104 108Z',
                    fill: FigInk.accent,
                    opacity: 0.55,
                  ),
                  FigShape.path(
                    'M103 97C108.5 99 111 104 109.5 110C106 108 103.5 103 103 97Z',
                    fill: FigInk.accent,
                    opacity: 0.55,
                  ),
                  FigGroup(
                    motion: 'st4-flS',
                    children: [
                      FigShape.path(
                        'M93 146A7 7 0 0 1 107 146C106 160 105 174 104 187A4 4 0 0 1 96 187C93 177 86.5 160 93 146Z',
                        fill: FigInk.far,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        motion: 'st4-flF',
                        children: [
                          FigShape.path(
                            'M95 184C99 182.5 103 182.5 105.5 184C109.5 185.5 113 187.5 115.5 189.5C117.2 191 116.6 193 114 193L95 193C92.2 193 91.5 190.5 92 188.5C92.5 186.2 93.5 184.6 95 184Z',
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                pose: FigPose.rotate(2, 100, 104),
                children: [
                  FigShape.path(
                    'M96.5 40L104.5 40L105.5 52C110 55 114 60 114.5 67C115 74 113 81 111 88C110 94 112.5 100 112 106C111.5 112 108 117 102 120L92 120C87 118 84.5 113 85 107C85.5 102 89 98 92 94C93 88 89.5 82 89 75C88.5 68 89.5 60 95.5 53Z',
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigShape.circle(
                    101,
                    30,
                    11.5,
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                ],
              ),
              FigGroup(
                pose: FigPose.rotate(-88, 100, 104),
                motion: 'st4-nlT',
                children: [
                  FigShape.path(
                    'M89 104A11 11 0 0 1 111 104C112.5 117 110 133 107 146A7 7 0 0 1 93 146C90.5 133 88 118 89 104Z',
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigShape.path(
                    'M104 108C110.5 113 111 130 105.5 141C103 131 101.5 118 104 108Z',
                    fill: FigInk.accent,
                  ),
                  FigShape.path(
                    'M103 97C108.5 99 111 104 109.5 110C106 108 103.5 103 103 97Z',
                    fill: FigInk.accent,
                  ),
                  FigGroup(
                    pose: FigPose.rotate(98, 100, 146),
                    motion: 'st4-nlS',
                    children: [
                      FigShape.path(
                        'M93 146A7 7 0 0 1 107 146C106 160 105 174 104 187A4 4 0 0 1 96 187C93 177 86.5 160 93 146Z',
                        fill: FigInk.near,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(18, 100, 188),
                        motion: 'st4-nlF',
                        children: [
                          FigShape.path(
                            'M95 184C99 182.5 103 182.5 105.5 184C109.5 185.5 113 187.5 115.5 189.5C117.2 191 116.6 193 114 193L95 193C92.2 193 91.5 190.5 92 188.5C92.5 186.2 93.5 184.6 95 184Z',
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                pose: FigPose.rotate(2, 100, 104),
                children: [
                  FigGroup(
                    pose: FigPose.rotate(36, 100, 60),
                    motion: 'st4-naU',
                    children: [
                      FigShape.path(
                        'M94 60A6 6 0 0 1 106 60L104.5 90A4.5 4.5 0 0 1 95.5 90Z',
                        fill: FigInk.near,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(-88, 100, 90),
                        children: [
                          FigShape.path(
                            'M95.5 90A4.5 4.5 0 0 1 104.5 90L103.5 113A3.5 3.5 0 0 1 96.5 113Z',
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                          FigShape.circle(
                            100,
                            117,
                            4.6,
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
  FigGroup(
    children: [
      FigShape.path('M34 196.5H166', stroke: FigInk.ground, strokeWidth: 2),
      FigGroup(
        pose: FigPose.translate(0, -2),
        motion: 'st5-root',
        children: [
          FigGroup(
            children: [
              FigGroup(
                pose: FigPose.rotate(4, 100, 104),
                children: [
                  FigGroup(
                    pose: FigPose.rotate(-34, 100, 60),
                    motion: 'st5-faU',
                    children: [
                      FigShape.path(
                        'M94 60A6 6 0 0 1 106 60L104.5 90A4.5 4.5 0 0 1 95.5 90Z',
                        fill: FigInk.far,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(-88, 100, 90),
                        children: [
                          FigShape.path(
                            'M95.5 90A4.5 4.5 0 0 1 104.5 90L103.5 113A3.5 3.5 0 0 1 96.5 113Z',
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                          FigShape.circle(
                            100,
                            117,
                            4.6,
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                motion: 'st5-flT',
                children: [
                  FigShape.path(
                    'M89 104A11 11 0 0 1 111 104C112.5 117 110 133 107 146A7 7 0 0 1 93 146C90.5 133 88 118 89 104Z',
                    fill: FigInk.far,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigShape.path(
                    'M95.5 109C89.5 115 89.5 131 94.5 142C97.5 131 98 119 95.5 109Z',
                    fill: FigInk.accent,
                    opacity: 0.55,
                  ),
                  FigGroup(
                    motion: 'st5-flS',
                    children: [
                      FigShape.path(
                        'M93 146A7 7 0 0 1 107 146C106 160 105 174 104 187A4 4 0 0 1 96 187C93 177 86.5 160 93 146Z',
                        fill: FigInk.far,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        motion: 'st5-flF',
                        children: [
                          FigShape.path(
                            'M95 184C99 182.5 103 182.5 105.5 184C109.5 185.5 113 187.5 115.5 189.5C117.2 191 116.6 193 114 193L95 193C92.2 193 91.5 190.5 92 188.5C92.5 186.2 93.5 184.6 95 184Z',
                            fill: FigInk.far,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                pose: FigPose.rotate(4, 100, 104),
                children: [
                  FigShape.path(
                    'M96.5 40L104.5 40L105.5 52C110 55 114 60 114.5 67C115 74 113 81 111 88C110 94 112.5 100 112 106C111.5 112 108 117 102 120L92 120C87 118 84.5 113 85 107C85.5 102 89 98 92 94C93 88 89.5 82 89 75C88.5 68 89.5 60 95.5 53Z',
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigShape.circle(
                    101,
                    30,
                    11.5,
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                ],
              ),
              FigGroup(
                pose: FigPose.rotate(4, 100, 104),
                motion: 'st5-nlT',
                children: [
                  FigShape.path(
                    'M89 104A11 11 0 0 1 111 104C112.5 117 110 133 107 146A7 7 0 0 1 93 146C90.5 133 88 118 89 104Z',
                    fill: FigInk.near,
                    stroke: FigInk.outline,
                    strokeWidth: 3.5,
                  ),
                  FigShape.path(
                    'M95.5 109C89.5 115 89.5 131 94.5 142C97.5 131 98 119 95.5 109Z',
                    fill: FigInk.accent,
                  ),
                  FigGroup(
                    pose: FigPose.rotate(145, 100, 146),
                    motion: 'st5-nlS',
                    children: [
                      FigShape.path(
                        'M93 146A7 7 0 0 1 107 146C106 160 105 174 104 187A4 4 0 0 1 96 187C93 177 86.5 160 93 146Z',
                        fill: FigInk.near,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(30, 100, 188),
                        motion: 'st5-nlF',
                        children: [
                          FigShape.path(
                            'M95 184C99 182.5 103 182.5 105.5 184C109.5 185.5 113 187.5 115.5 189.5C117.2 191 116.6 193 114 193L95 193C92.2 193 91.5 190.5 92 188.5C92.5 186.2 93.5 184.6 95 184Z',
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              FigGroup(
                pose: FigPose.rotate(4, 100, 104),
                children: [
                  FigGroup(
                    pose: FigPose.rotate(26, 100, 60),
                    motion: 'st5-naU',
                    children: [
                      FigShape.path(
                        'M94 60A6 6 0 0 1 106 60L104.5 90A4.5 4.5 0 0 1 95.5 90Z',
                        fill: FigInk.near,
                        stroke: FigInk.outline,
                        strokeWidth: 3.5,
                      ),
                      FigGroup(
                        pose: FigPose.rotate(-88, 100, 90),
                        children: [
                          FigShape.path(
                            'M95.5 90A4.5 4.5 0 0 1 104.5 90L103.5 113A3.5 3.5 0 0 1 96.5 113Z',
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                          FigShape.circle(
                            100,
                            117,
                            4.6,
                            fill: FigInk.near,
                            stroke: FigInk.outline,
                            strokeWidth: 3.5,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  ),
];

/// 그림 안 부분별 움직임. 한 바퀴 시간(초)과 시점별 자세.
const stretchMotions = <String, FigMotion>{
  'st1-nlT': FigMotion(3.2, [
    FigKey(0, FigPose.rotate(-37.8, 100, 104)),
    FigKey(0.08333, FigPose.rotate(-39.4, 100, 104)),
    FigKey(0.16667, FigPose.rotate(-40, 100, 104)),
    FigKey(0.25, FigPose.rotate(-40.1, 100, 104)),
    FigKey(0.33333, FigPose.rotate(-40, 100, 104)),
    FigKey(0.41667, FigPose.rotate(-39.4, 100, 104)),
    FigKey(0.5, FigPose.rotate(-37.8, 100, 104)),
    FigKey(0.58333, FigPose.rotate(-35.5, 100, 104)),
    FigKey(0.66667, FigPose.rotate(-33.2, 100, 104)),
    FigKey(0.75, FigPose.rotate(-32.3, 100, 104)),
    FigKey(0.83333, FigPose.rotate(-33.2, 100, 104)),
    FigKey(0.91667, FigPose.rotate(-35.5, 100, 104)),
    FigKey(1, FigPose.rotate(-37.8, 100, 104)),
  ]),
  'st1-nlS': FigMotion(3.2, [
    FigKey(0, FigPose.rotate(41.9, 100, 146)),
    FigKey(0.08333, FigPose.rotate(41.6, 100, 146)),
    FigKey(0.16667, FigPose.rotate(40.3, 100, 146)),
    FigKey(0.25, FigPose.rotate(39.6, 100, 146)),
    FigKey(0.33333, FigPose.rotate(40.3, 100, 146)),
    FigKey(0.41667, FigPose.rotate(41.6, 100, 146)),
    FigKey(0.5, FigPose.rotate(41.9, 100, 146)),
    FigKey(0.58333, FigPose.rotate(40.5, 100, 146)),
    FigKey(0.66667, FigPose.rotate(38.3, 100, 146)),
    FigKey(0.75, FigPose.rotate(37.3, 100, 146)),
    FigKey(0.83333, FigPose.rotate(38.3, 100, 146)),
    FigKey(0.91667, FigPose.rotate(40.5, 100, 146)),
    FigKey(1, FigPose.rotate(41.9, 100, 146)),
  ]),
  'st1-nlF': FigMotion(3.2, [
    FigKey(0, FigPose.rotate(46, 100, 188)),
    FigKey(0.08333, FigPose.rotate(56.8, 100, 188)),
    FigKey(0.16667, FigPose.rotate(65.3, 100, 188)),
    FigKey(0.25, FigPose.rotate(68.5, 100, 188)),
    FigKey(0.33333, FigPose.rotate(65.3, 100, 188)),
    FigKey(0.41667, FigPose.rotate(56.8, 100, 188)),
    FigKey(0.5, FigPose.rotate(46, 100, 188)),
    FigKey(0.58333, FigPose.rotate(36, 100, 188)),
    FigKey(0.66667, FigPose.rotate(29.3, 100, 188)),
    FigKey(0.75, FigPose.rotate(27, 100, 188)),
    FigKey(0.83333, FigPose.rotate(29.3, 100, 188)),
    FigKey(0.91667, FigPose.rotate(36, 100, 188)),
    FigKey(1, FigPose.rotate(46, 100, 188)),
  ]),
  'st1-spin': FigMotion(3.2, [
    FigKey(0, FigPose.rotate(0, 122.8, 179.1)),
    FigKey(1, FigPose.rotate(360, 122.8, 179.1)),
  ]),
  'st2-lean': FigMotion(1.8, [
    FigKey(0, FigPose.rotate(-3, 100, 104)),
    FigKey(0.08333, FigPose.rotate(-2.6, 100, 104)),
    FigKey(0.16667, FigPose.rotate(-1.5, 100, 104)),
    FigKey(0.25, FigPose.rotate(0, 100, 104)),
    FigKey(0.33333, FigPose.rotate(1.5, 100, 104)),
    FigKey(0.41667, FigPose.rotate(2.6, 100, 104)),
    FigKey(0.5, FigPose.rotate(3, 100, 104)),
    FigKey(0.58333, FigPose.rotate(2.6, 100, 104)),
    FigKey(0.66667, FigPose.rotate(1.5, 100, 104)),
    FigKey(0.75, FigPose.rotate(0, 100, 104)),
    FigKey(0.83333, FigPose.rotate(-1.5, 100, 104)),
    FigKey(0.91667, FigPose.rotate(-2.6, 100, 104)),
    FigKey(1, FigPose.rotate(-3, 100, 104)),
  ]),
  'st2-nlT': FigMotion(1.8, [
    FigKey(0, FigPose.rotate(-55, 100, 104)),
    FigKey(0.08333, FigPose.rotate(-49.3, 100, 104)),
    FigKey(0.16667, FigPose.rotate(-33.8, 100, 104)),
    FigKey(0.25, FigPose.rotate(-12.5, 100, 104)),
    FigKey(0.33333, FigPose.rotate(8.7, 100, 104)),
    FigKey(0.41667, FigPose.rotate(24.3, 100, 104)),
    FigKey(0.5, FigPose.rotate(30, 100, 104)),
    FigKey(0.58333, FigPose.rotate(24.3, 100, 104)),
    FigKey(0.66667, FigPose.rotate(8.8, 100, 104)),
    FigKey(0.75, FigPose.rotate(-12.5, 100, 104)),
    FigKey(0.83333, FigPose.rotate(-33.8, 100, 104)),
    FigKey(0.91667, FigPose.rotate(-49.3, 100, 104)),
    FigKey(1, FigPose.rotate(-55, 100, 104)),
  ]),
  'st2-nlS': FigMotion(1.8, [
    FigKey(0, FigPose.rotate(10, 100, 146)),
    FigKey(0.08333, FigPose.rotate(10.1, 100, 146)),
    FigKey(0.16667, FigPose.rotate(11.7, 100, 146)),
    FigKey(0.25, FigPose.rotate(30.3, 100, 146)),
    FigKey(0.33333, FigPose.rotate(34.8, 100, 146)),
    FigKey(0.41667, FigPose.rotate(16.8, 100, 146)),
    FigKey(0.5, FigPose.rotate(13.2, 100, 146)),
    FigKey(0.58333, FigPose.rotate(16.8, 100, 146)),
    FigKey(0.66667, FigPose.rotate(34.8, 100, 146)),
    FigKey(0.75, FigPose.rotate(30.3, 100, 146)),
    FigKey(0.83333, FigPose.rotate(11.7, 100, 146)),
    FigKey(0.91667, FigPose.rotate(10.1, 100, 146)),
    FigKey(1, FigPose.rotate(10, 100, 146)),
  ]),
  'st2-nlF': FigMotion(1.8, [
    FigKey(0, FigPose.rotate(8, 100, 188)),
    FigKey(0.08333, FigPose.rotate(7.9, 100, 188)),
    FigKey(0.16667, FigPose.rotate(6.7, 100, 188)),
    FigKey(0.25, FigPose.rotate(-7.6, 100, 188)),
    FigKey(0.33333, FigPose.rotate(-11, 100, 188)),
    FigKey(0.41667, FigPose.rotate(2.7, 100, 188)),
    FigKey(0.5, FigPose.rotate(5.6, 100, 188)),
    FigKey(0.58333, FigPose.rotate(2.7, 100, 188)),
    FigKey(0.66667, FigPose.rotate(-11, 100, 188)),
    FigKey(0.75, FigPose.rotate(-7.6, 100, 188)),
    FigKey(0.83333, FigPose.rotate(6.7, 100, 188)),
    FigKey(0.91667, FigPose.rotate(7.9, 100, 188)),
    FigKey(1, FigPose.rotate(8, 100, 188)),
  ]),
  'st2-naU': FigMotion(1.8, [
    FigKey(0, FigPose.rotate(35.2, 100, 60)),
    FigKey(0.08333, FigPose.rotate(34.8, 100, 60)),
    FigKey(0.16667, FigPose.rotate(33.7, 100, 60)),
    FigKey(0.25, FigPose.rotate(32.2, 100, 60)),
    FigKey(0.33333, FigPose.rotate(30.7, 100, 60)),
    FigKey(0.41667, FigPose.rotate(29.6, 100, 60)),
    FigKey(0.5, FigPose.rotate(29.2, 100, 60)),
    FigKey(0.58333, FigPose.rotate(29.6, 100, 60)),
    FigKey(0.66667, FigPose.rotate(30.7, 100, 60)),
    FigKey(0.75, FigPose.rotate(32.2, 100, 60)),
    FigKey(0.83333, FigPose.rotate(33.7, 100, 60)),
    FigKey(0.91667, FigPose.rotate(34.8, 100, 60)),
    FigKey(1, FigPose.rotate(35.2, 100, 60)),
  ]),
  'st2-faU': FigMotion(1.8, [
    FigKey(0, FigPose.rotate(-69, 100, 60)),
    FigKey(0.08333, FigPose.rotate(-69.4, 100, 60)),
    FigKey(0.16667, FigPose.rotate(-70.5, 100, 60)),
    FigKey(0.25, FigPose.rotate(-72, 100, 60)),
    FigKey(0.33333, FigPose.rotate(-73.5, 100, 60)),
    FigKey(0.41667, FigPose.rotate(-74.6, 100, 60)),
    FigKey(0.5, FigPose.rotate(-75, 100, 60)),
    FigKey(0.58333, FigPose.rotate(-74.6, 100, 60)),
    FigKey(0.66667, FigPose.rotate(-73.5, 100, 60)),
    FigKey(0.75, FigPose.rotate(-72, 100, 60)),
    FigKey(0.83333, FigPose.rotate(-70.5, 100, 60)),
    FigKey(0.91667, FigPose.rotate(-69.4, 100, 60)),
    FigKey(1, FigPose.rotate(-69, 100, 60)),
  ]),
  'st3-root': FigMotion(2.6, [
    FigKey(0, FigPose.translate(0, 8)),
    FigKey(0.08333, FigPose.translate(0.1, 10.1)),
    FigKey(0.16667, FigPose.translate(0.5, 16)),
    FigKey(0.25, FigPose.translate(1, 24)),
    FigKey(0.33333, FigPose.translate(1.5, 32)),
    FigKey(0.41667, FigPose.translate(1.9, 37.9)),
    FigKey(0.5, FigPose.translate(2, 40)),
    FigKey(0.58333, FigPose.translate(1.9, 37.9)),
    FigKey(0.66667, FigPose.translate(1.5, 32)),
    FigKey(0.75, FigPose.translate(1, 24)),
    FigKey(0.83333, FigPose.translate(0.5, 16)),
    FigKey(0.91667, FigPose.translate(0.1, 10.1)),
    FigKey(1, FigPose.translate(0, 8)),
  ]),
  'st3-nlT': FigMotion(2.6, [
    FigKey(0, FigPose.rotate(-31.7, 100, 104)),
    FigKey(0.08333, FigPose.rotate(-39.3, 100, 104)),
    FigKey(0.16667, FigPose.rotate(-51.7, 100, 104)),
    FigKey(0.25, FigPose.rotate(-64.2, 100, 104)),
    FigKey(0.33333, FigPose.rotate(-75.1, 100, 104)),
    FigKey(0.41667, FigPose.rotate(-82.8, 100, 104)),
    FigKey(0.5, FigPose.rotate(-85.7, 100, 104)),
    FigKey(0.58333, FigPose.rotate(-82.8, 100, 104)),
    FigKey(0.66667, FigPose.rotate(-75.1, 100, 104)),
    FigKey(0.75, FigPose.rotate(-64.2, 100, 104)),
    FigKey(0.83333, FigPose.rotate(-51.7, 100, 104)),
    FigKey(0.91667, FigPose.rotate(-39.3, 100, 104)),
    FigKey(1, FigPose.rotate(-31.7, 100, 104)),
  ]),
  'st3-nlS': FigMotion(2.6, [
    FigKey(0, FigPose.rotate(15.2, 100, 146)),
    FigKey(0.08333, FigPose.rotate(29.4, 100, 146)),
    FigKey(0.16667, FigPose.rotate(51, 100, 146)),
    FigKey(0.25, FigPose.rotate(70.8, 100, 146)),
    FigKey(0.33333, FigPose.rotate(86.2, 100, 146)),
    FigKey(0.41667, FigPose.rotate(96, 100, 146)),
    FigKey(0.5, FigPose.rotate(99.3, 100, 146)),
    FigKey(0.58333, FigPose.rotate(96, 100, 146)),
    FigKey(0.66667, FigPose.rotate(86.2, 100, 146)),
    FigKey(0.75, FigPose.rotate(70.8, 100, 146)),
    FigKey(0.83333, FigPose.rotate(51, 100, 146)),
    FigKey(0.91667, FigPose.rotate(29.4, 100, 146)),
    FigKey(1, FigPose.rotate(15.2, 100, 146)),
  ]),
  'st3-nlF': FigMotion(2.6, [
    FigKey(0, FigPose.rotate(16.5, 100, 188)),
    FigKey(0.08333, FigPose.rotate(9.9, 100, 188)),
    FigKey(0.16667, FigPose.rotate(0.7, 100, 188)),
    FigKey(0.25, FigPose.rotate(-6.6, 100, 188)),
    FigKey(0.33333, FigPose.rotate(-11.1, 100, 188)),
    FigKey(0.41667, FigPose.rotate(-13.1, 100, 188)),
    FigKey(0.5, FigPose.rotate(-13.6, 100, 188)),
    FigKey(0.58333, FigPose.rotate(-13.1, 100, 188)),
    FigKey(0.66667, FigPose.rotate(-11.1, 100, 188)),
    FigKey(0.75, FigPose.rotate(-6.6, 100, 188)),
    FigKey(0.83333, FigPose.rotate(0.7, 100, 188)),
    FigKey(0.91667, FigPose.rotate(9.9, 100, 188)),
    FigKey(1, FigPose.rotate(16.5, 100, 188)),
  ]),
  'st3-flT': FigMotion(2.6, [
    FigKey(0, FigPose.rotate(22.8, 100, 104)),
    FigKey(0.08333, FigPose.rotate(17.7, 100, 104)),
    FigKey(0.16667, FigPose.rotate(9.8, 100, 104)),
    FigKey(0.25, FigPose.rotate(4, 100, 104)),
    FigKey(0.33333, FigPose.rotate(1.1, 100, 104)),
    FigKey(0.41667, FigPose.rotate(0.4, 100, 104)),
    FigKey(0.5, FigPose.rotate(0.5, 100, 104)),
    FigKey(0.58333, FigPose.rotate(0.4, 100, 104)),
    FigKey(0.66667, FigPose.rotate(1.1, 100, 104)),
    FigKey(0.75, FigPose.rotate(4, 100, 104)),
    FigKey(0.83333, FigPose.rotate(9.8, 100, 104)),
    FigKey(0.91667, FigPose.rotate(17.7, 100, 104)),
    FigKey(1, FigPose.rotate(22.8, 100, 104)),
  ]),
  'st3-flS': FigMotion(2.6, [
    FigKey(0, FigPose.rotate(22.1, 100, 146)),
    FigKey(0.08333, FigPose.rotate(34, 100, 146)),
    FigKey(0.16667, FigPose.rotate(54.5, 100, 146)),
    FigKey(0.25, FigPose.rotate(73.5, 100, 146)),
    FigKey(0.33333, FigPose.rotate(88.2, 100, 146)),
    FigKey(0.41667, FigPose.rotate(97.2, 100, 146)),
    FigKey(0.5, FigPose.rotate(100.2, 100, 146)),
    FigKey(0.58333, FigPose.rotate(97.2, 100, 146)),
    FigKey(0.66667, FigPose.rotate(88.2, 100, 146)),
    FigKey(0.75, FigPose.rotate(73.5, 100, 146)),
    FigKey(0.83333, FigPose.rotate(54.5, 100, 146)),
    FigKey(0.91667, FigPose.rotate(34, 100, 146)),
    FigKey(1, FigPose.rotate(22.1, 100, 146)),
  ]),
  'st3-flF': FigMotion(2.6, [
    FigKey(0, FigPose.rotate(-6.9, 100, 188)),
    FigKey(0.08333, FigPose.rotate(-11.9, 100, 188)),
    FigKey(0.16667, FigPose.rotate(-19.8, 100, 188)),
    FigKey(0.25, FigPose.rotate(-26.5, 100, 188)),
    FigKey(0.33333, FigPose.rotate(-31.8, 100, 188)),
    FigKey(0.41667, FigPose.rotate(-35.4, 100, 188)),
    FigKey(0.5, FigPose.rotate(-36.7, 100, 188)),
    FigKey(0.58333, FigPose.rotate(-35.4, 100, 188)),
    FigKey(0.66667, FigPose.rotate(-31.8, 100, 188)),
    FigKey(0.75, FigPose.rotate(-26.5, 100, 188)),
    FigKey(0.83333, FigPose.rotate(-19.8, 100, 188)),
    FigKey(0.91667, FigPose.rotate(-11.9, 100, 188)),
    FigKey(1, FigPose.rotate(-6.9, 100, 188)),
  ]),
  'st4-root': FigMotion(1.1, [
    FigKey(0, FigPose.translate(0, 0)),
    FigKey(0.08333, FigPose.translate(0, -0.5)),
    FigKey(0.16667, FigPose.translate(0, -1.5)),
    FigKey(0.25, FigPose.translate(0, -2)),
    FigKey(0.33333, FigPose.translate(0, -1.5)),
    FigKey(0.41667, FigPose.translate(0, -0.5)),
    FigKey(0.5, FigPose.translate(0, 0)),
    FigKey(0.58333, FigPose.translate(0, -0.5)),
    FigKey(0.66667, FigPose.translate(0, -1.5)),
    FigKey(0.75, FigPose.translate(0, -2)),
    FigKey(0.83333, FigPose.translate(0, -1.5)),
    FigKey(0.91667, FigPose.translate(0, -0.5)),
    FigKey(1, FigPose.translate(0, 0)),
  ]),
  'st4-nlT': FigMotion(1.1, [
    FigKey(0, FigPose.rotate(0, 100, 104)),
    FigKey(0.08333, FigPose.rotate(-22, 100, 104)),
    FigKey(0.16667, FigPose.rotate(-66, 100, 104)),
    FigKey(0.25, FigPose.rotate(-88, 100, 104)),
    FigKey(0.33333, FigPose.rotate(-66, 100, 104)),
    FigKey(0.41667, FigPose.rotate(-22, 100, 104)),
    FigKey(0.5, FigPose.rotate(0, 100, 104)),
    FigKey(0.58333, FigPose.rotate(0, 100, 104)),
    FigKey(0.66667, FigPose.rotate(0, 100, 104)),
    FigKey(0.75, FigPose.rotate(0, 100, 104)),
    FigKey(0.83333, FigPose.rotate(0, 100, 104)),
    FigKey(0.91667, FigPose.rotate(0, 100, 104)),
    FigKey(1, FigPose.rotate(0, 100, 104)),
  ]),
  'st4-nlS': FigMotion(1.1, [
    FigKey(0, FigPose.rotate(0, 100, 146)),
    FigKey(0.08333, FigPose.rotate(24.5, 100, 146)),
    FigKey(0.16667, FigPose.rotate(73.5, 100, 146)),
    FigKey(0.25, FigPose.rotate(98, 100, 146)),
    FigKey(0.33333, FigPose.rotate(73.5, 100, 146)),
    FigKey(0.41667, FigPose.rotate(24.5, 100, 146)),
    FigKey(0.5, FigPose.rotate(0, 100, 146)),
    FigKey(0.58333, FigPose.rotate(0, 100, 146)),
    FigKey(0.66667, FigPose.rotate(0, 100, 146)),
    FigKey(0.75, FigPose.rotate(0, 100, 146)),
    FigKey(0.83333, FigPose.rotate(0, 100, 146)),
    FigKey(0.91667, FigPose.rotate(0, 100, 146)),
    FigKey(1, FigPose.rotate(0, 100, 146)),
  ]),
  'st4-nlF': FigMotion(1.1, [
    FigKey(0, FigPose.rotate(0, 100, 188)),
    FigKey(0.08333, FigPose.rotate(4.5, 100, 188)),
    FigKey(0.16667, FigPose.rotate(13.5, 100, 188)),
    FigKey(0.25, FigPose.rotate(18, 100, 188)),
    FigKey(0.33333, FigPose.rotate(13.5, 100, 188)),
    FigKey(0.41667, FigPose.rotate(4.5, 100, 188)),
    FigKey(0.5, FigPose.rotate(0, 100, 188)),
    FigKey(0.58333, FigPose.rotate(0, 100, 188)),
    FigKey(0.66667, FigPose.rotate(0, 100, 188)),
    FigKey(0.75, FigPose.rotate(0, 100, 188)),
    FigKey(0.83333, FigPose.rotate(0, 100, 188)),
    FigKey(0.91667, FigPose.rotate(0, 100, 188)),
    FigKey(1, FigPose.rotate(0, 100, 188)),
  ]),
  'st4-flT': FigMotion(1.1, [
    FigKey(0, FigPose.rotate(0, 100, 104)),
    FigKey(0.08333, FigPose.rotate(0, 100, 104)),
    FigKey(0.16667, FigPose.rotate(0, 100, 104)),
    FigKey(0.25, FigPose.rotate(0, 100, 104)),
    FigKey(0.33333, FigPose.rotate(0, 100, 104)),
    FigKey(0.41667, FigPose.rotate(0, 100, 104)),
    FigKey(0.5, FigPose.rotate(0, 100, 104)),
    FigKey(0.58333, FigPose.rotate(-22, 100, 104)),
    FigKey(0.66667, FigPose.rotate(-66, 100, 104)),
    FigKey(0.75, FigPose.rotate(-88, 100, 104)),
    FigKey(0.83333, FigPose.rotate(-66, 100, 104)),
    FigKey(0.91667, FigPose.rotate(-22, 100, 104)),
    FigKey(1, FigPose.rotate(0, 100, 104)),
  ]),
  'st4-flS': FigMotion(1.1, [
    FigKey(0, FigPose.rotate(0, 100, 146)),
    FigKey(0.08333, FigPose.rotate(0, 100, 146)),
    FigKey(0.16667, FigPose.rotate(0, 100, 146)),
    FigKey(0.25, FigPose.rotate(0, 100, 146)),
    FigKey(0.33333, FigPose.rotate(0, 100, 146)),
    FigKey(0.41667, FigPose.rotate(0, 100, 146)),
    FigKey(0.5, FigPose.rotate(0, 100, 146)),
    FigKey(0.58333, FigPose.rotate(24.5, 100, 146)),
    FigKey(0.66667, FigPose.rotate(73.5, 100, 146)),
    FigKey(0.75, FigPose.rotate(98, 100, 146)),
    FigKey(0.83333, FigPose.rotate(73.5, 100, 146)),
    FigKey(0.91667, FigPose.rotate(24.5, 100, 146)),
    FigKey(1, FigPose.rotate(0, 100, 146)),
  ]),
  'st4-flF': FigMotion(1.1, [
    FigKey(0, FigPose.rotate(0, 100, 188)),
    FigKey(0.08333, FigPose.rotate(0, 100, 188)),
    FigKey(0.16667, FigPose.rotate(0, 100, 188)),
    FigKey(0.25, FigPose.rotate(0, 100, 188)),
    FigKey(0.33333, FigPose.rotate(0, 100, 188)),
    FigKey(0.41667, FigPose.rotate(0, 100, 188)),
    FigKey(0.5, FigPose.rotate(0, 100, 188)),
    FigKey(0.58333, FigPose.rotate(4.5, 100, 188)),
    FigKey(0.66667, FigPose.rotate(13.5, 100, 188)),
    FigKey(0.75, FigPose.rotate(18, 100, 188)),
    FigKey(0.83333, FigPose.rotate(13.5, 100, 188)),
    FigKey(0.91667, FigPose.rotate(4.5, 100, 188)),
    FigKey(1, FigPose.rotate(0, 100, 188)),
  ]),
  'st4-naU': FigMotion(1.1, [
    FigKey(0, FigPose.rotate(-2, 100, 60)),
    FigKey(0.08333, FigPose.rotate(17, 100, 60)),
    FigKey(0.16667, FigPose.rotate(30.9, 100, 60)),
    FigKey(0.25, FigPose.rotate(36, 100, 60)),
    FigKey(0.33333, FigPose.rotate(30.9, 100, 60)),
    FigKey(0.41667, FigPose.rotate(17, 100, 60)),
    FigKey(0.5, FigPose.rotate(-2, 100, 60)),
    FigKey(0.58333, FigPose.rotate(-21, 100, 60)),
    FigKey(0.66667, FigPose.rotate(-34.9, 100, 60)),
    FigKey(0.75, FigPose.rotate(-40, 100, 60)),
    FigKey(0.83333, FigPose.rotate(-34.9, 100, 60)),
    FigKey(0.91667, FigPose.rotate(-21, 100, 60)),
    FigKey(1, FigPose.rotate(-2, 100, 60)),
  ]),
  'st4-faU': FigMotion(1.1, [
    FigKey(0, FigPose.rotate(-2, 100, 60)),
    FigKey(0.08333, FigPose.rotate(-21, 100, 60)),
    FigKey(0.16667, FigPose.rotate(-34.9, 100, 60)),
    FigKey(0.25, FigPose.rotate(-40, 100, 60)),
    FigKey(0.33333, FigPose.rotate(-34.9, 100, 60)),
    FigKey(0.41667, FigPose.rotate(-21, 100, 60)),
    FigKey(0.5, FigPose.rotate(-2, 100, 60)),
    FigKey(0.58333, FigPose.rotate(17, 100, 60)),
    FigKey(0.66667, FigPose.rotate(30.9, 100, 60)),
    FigKey(0.75, FigPose.rotate(36, 100, 60)),
    FigKey(0.83333, FigPose.rotate(30.9, 100, 60)),
    FigKey(0.91667, FigPose.rotate(17, 100, 60)),
    FigKey(1, FigPose.rotate(-2, 100, 60)),
  ]),
  'st5-root': FigMotion(1, [
    FigKey(0, FigPose.translate(0, 0)),
    FigKey(0.08333, FigPose.translate(0, -0.5)),
    FigKey(0.16667, FigPose.translate(0, -1.5)),
    FigKey(0.25, FigPose.translate(0, -2)),
    FigKey(0.33333, FigPose.translate(0, -1.5)),
    FigKey(0.41667, FigPose.translate(0, -0.5)),
    FigKey(0.5, FigPose.translate(0, 0)),
    FigKey(0.58333, FigPose.translate(0, -0.5)),
    FigKey(0.66667, FigPose.translate(0, -1.5)),
    FigKey(0.75, FigPose.translate(0, -2)),
    FigKey(0.83333, FigPose.translate(0, -1.5)),
    FigKey(0.91667, FigPose.translate(0, -0.5)),
    FigKey(1, FigPose.translate(0, 0)),
  ]),
  'st5-nlT': FigMotion(1, [
    FigKey(0, FigPose.rotate(0, 100, 104)),
    FigKey(0.08333, FigPose.rotate(1, 100, 104)),
    FigKey(0.16667, FigPose.rotate(3, 100, 104)),
    FigKey(0.25, FigPose.rotate(4, 100, 104)),
    FigKey(0.33333, FigPose.rotate(3, 100, 104)),
    FigKey(0.41667, FigPose.rotate(1, 100, 104)),
    FigKey(0.5, FigPose.rotate(0, 100, 104)),
    FigKey(0.58333, FigPose.rotate(0, 100, 104)),
    FigKey(0.66667, FigPose.rotate(0, 100, 104)),
    FigKey(0.75, FigPose.rotate(0, 100, 104)),
    FigKey(0.83333, FigPose.rotate(0, 100, 104)),
    FigKey(0.91667, FigPose.rotate(0, 100, 104)),
    FigKey(1, FigPose.rotate(0, 100, 104)),
  ]),
  'st5-nlS': FigMotion(1, [
    FigKey(0, FigPose.rotate(0, 100, 146)),
    FigKey(0.08333, FigPose.rotate(36.2, 100, 146)),
    FigKey(0.16667, FigPose.rotate(108.7, 100, 146)),
    FigKey(0.25, FigPose.rotate(145, 100, 146)),
    FigKey(0.33333, FigPose.rotate(108.8, 100, 146)),
    FigKey(0.41667, FigPose.rotate(36.2, 100, 146)),
    FigKey(0.5, FigPose.rotate(0, 100, 146)),
    FigKey(0.58333, FigPose.rotate(0, 100, 146)),
    FigKey(0.66667, FigPose.rotate(0, 100, 146)),
    FigKey(0.75, FigPose.rotate(0, 100, 146)),
    FigKey(0.83333, FigPose.rotate(0, 100, 146)),
    FigKey(0.91667, FigPose.rotate(0, 100, 146)),
    FigKey(1, FigPose.rotate(0, 100, 146)),
  ]),
  'st5-nlF': FigMotion(1, [
    FigKey(0, FigPose.rotate(0, 100, 188)),
    FigKey(0.08333, FigPose.rotate(7.5, 100, 188)),
    FigKey(0.16667, FigPose.rotate(22.5, 100, 188)),
    FigKey(0.25, FigPose.rotate(30, 100, 188)),
    FigKey(0.33333, FigPose.rotate(22.5, 100, 188)),
    FigKey(0.41667, FigPose.rotate(7.5, 100, 188)),
    FigKey(0.5, FigPose.rotate(0, 100, 188)),
    FigKey(0.58333, FigPose.rotate(0, 100, 188)),
    FigKey(0.66667, FigPose.rotate(0, 100, 188)),
    FigKey(0.75, FigPose.rotate(0, 100, 188)),
    FigKey(0.83333, FigPose.rotate(0, 100, 188)),
    FigKey(0.91667, FigPose.rotate(0, 100, 188)),
    FigKey(1, FigPose.rotate(0, 100, 188)),
  ]),
  'st5-flT': FigMotion(1, [
    FigKey(0, FigPose.rotate(0, 100, 104)),
    FigKey(0.08333, FigPose.rotate(0, 100, 104)),
    FigKey(0.16667, FigPose.rotate(0, 100, 104)),
    FigKey(0.25, FigPose.rotate(0, 100, 104)),
    FigKey(0.33333, FigPose.rotate(0, 100, 104)),
    FigKey(0.41667, FigPose.rotate(0, 100, 104)),
    FigKey(0.5, FigPose.rotate(0, 100, 104)),
    FigKey(0.58333, FigPose.rotate(1, 100, 104)),
    FigKey(0.66667, FigPose.rotate(3, 100, 104)),
    FigKey(0.75, FigPose.rotate(4, 100, 104)),
    FigKey(0.83333, FigPose.rotate(3, 100, 104)),
    FigKey(0.91667, FigPose.rotate(1, 100, 104)),
    FigKey(1, FigPose.rotate(0, 100, 104)),
  ]),
  'st5-flS': FigMotion(1, [
    FigKey(0, FigPose.rotate(0, 100, 146)),
    FigKey(0.08333, FigPose.rotate(0, 100, 146)),
    FigKey(0.16667, FigPose.rotate(0, 100, 146)),
    FigKey(0.25, FigPose.rotate(0, 100, 146)),
    FigKey(0.33333, FigPose.rotate(0, 100, 146)),
    FigKey(0.41667, FigPose.rotate(0, 100, 146)),
    FigKey(0.5, FigPose.rotate(0, 100, 146)),
    FigKey(0.58333, FigPose.rotate(36.3, 100, 146)),
    FigKey(0.66667, FigPose.rotate(108.7, 100, 146)),
    FigKey(0.75, FigPose.rotate(145, 100, 146)),
    FigKey(0.83333, FigPose.rotate(108.7, 100, 146)),
    FigKey(0.91667, FigPose.rotate(36.3, 100, 146)),
    FigKey(1, FigPose.rotate(0, 100, 146)),
  ]),
  'st5-flF': FigMotion(1, [
    FigKey(0, FigPose.rotate(0, 100, 188)),
    FigKey(0.08333, FigPose.rotate(0, 100, 188)),
    FigKey(0.16667, FigPose.rotate(0, 100, 188)),
    FigKey(0.25, FigPose.rotate(0, 100, 188)),
    FigKey(0.33333, FigPose.rotate(0, 100, 188)),
    FigKey(0.41667, FigPose.rotate(0, 100, 188)),
    FigKey(0.5, FigPose.rotate(0, 100, 188)),
    FigKey(0.58333, FigPose.rotate(7.5, 100, 188)),
    FigKey(0.66667, FigPose.rotate(22.5, 100, 188)),
    FigKey(0.75, FigPose.rotate(30, 100, 188)),
    FigKey(0.83333, FigPose.rotate(22.5, 100, 188)),
    FigKey(0.91667, FigPose.rotate(7.5, 100, 188)),
    FigKey(1, FigPose.rotate(0, 100, 188)),
  ]),
  'st5-naU': FigMotion(1, [
    FigKey(0, FigPose.rotate(-4, 100, 60)),
    FigKey(0.08333, FigPose.rotate(11, 100, 60)),
    FigKey(0.16667, FigPose.rotate(22, 100, 60)),
    FigKey(0.25, FigPose.rotate(26, 100, 60)),
    FigKey(0.33333, FigPose.rotate(22, 100, 60)),
    FigKey(0.41667, FigPose.rotate(11, 100, 60)),
    FigKey(0.5, FigPose.rotate(-4, 100, 60)),
    FigKey(0.58333, FigPose.rotate(-19, 100, 60)),
    FigKey(0.66667, FigPose.rotate(-30, 100, 60)),
    FigKey(0.75, FigPose.rotate(-34, 100, 60)),
    FigKey(0.83333, FigPose.rotate(-30, 100, 60)),
    FigKey(0.91667, FigPose.rotate(-19, 100, 60)),
    FigKey(1, FigPose.rotate(-4, 100, 60)),
  ]),
  'st5-faU': FigMotion(1, [
    FigKey(0, FigPose.rotate(-4, 100, 60)),
    FigKey(0.08333, FigPose.rotate(-19, 100, 60)),
    FigKey(0.16667, FigPose.rotate(-30, 100, 60)),
    FigKey(0.25, FigPose.rotate(-34, 100, 60)),
    FigKey(0.33333, FigPose.rotate(-30, 100, 60)),
    FigKey(0.41667, FigPose.rotate(-19, 100, 60)),
    FigKey(0.5, FigPose.rotate(-4, 100, 60)),
    FigKey(0.58333, FigPose.rotate(11, 100, 60)),
    FigKey(0.66667, FigPose.rotate(22, 100, 60)),
    FigKey(0.75, FigPose.rotate(26, 100, 60)),
    FigKey(0.83333, FigPose.rotate(22, 100, 60)),
    FigKey(0.91667, FigPose.rotate(11, 100, 60)),
    FigKey(1, FigPose.rotate(-4, 100, 60)),
  ]),
};
