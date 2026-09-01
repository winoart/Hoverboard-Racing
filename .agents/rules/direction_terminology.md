# 방향 지시(Direction Terminology) 가이드라인

로블록스 호버보드 레이싱 프로젝트에서 "방향"에 대한 유저의 지시를 처리할 때 다음의 엄격한 기준을 따릅니다.

## 1. 카메라 방향 (Camera LookVector)
- **접근 방법**: `workspace.CurrentCamera.CFrame.LookVector`
- **의미**: 3인칭 백뷰 카메라가 바라보는 정면. 유저의 시야와 정확히 일치함.
- **적용 대상**: 미사일(투사체) 발사, 플레이어가 바라보는 앞쪽으로 무언가를 쏠 때 가장 우선적으로 사용해야 함.
- **키워드**: "카메라가 바라보는 방향", "내 눈앞", "시야 정면"

## 2. 모델 방향 (Model LookVector)
- **접근 방법**: `Model.PrimaryPart.CFrame.LookVector`
- **의미**: 3D 기체(호버보드) 자체가 가진 수학적 정면.
- **적용 대상**: 기체의 전조등, 모델의 축 방향을 기준으로 이펙트를 붙일 때.
- **주의점**: 모델링 시 Z축이 아닌 X축 등으로 만들어졌을 수 있으므로 시각적 오류가 날 경우 `-LookVector`나 `RightVector`로 보정해야 할 수 있음.

## 3. 캐릭터 방향 (Character LookVector)
- **접근 방법**: `Character.PrimaryPart.CFrame.LookVector`
- **의미**: 플레이어의 몸통(가슴팍)이 바라보는 방향.
- **주의점**: 호버보드 탑승 시(Stance) 플레이어가 옆을 보고 있으므로 발사체 방향 기준으로 절대 사용 금지.

## 4. 이동 방향 (Velocity Vector)
- **접근 방법**: `BasePart.AssemblyLinearVelocity.Unit`
- **의미**: 관성에 의해 실제로 물리적인 이동이 일어나는 방향.
- **적용 대상**: 먼지 입자(Particle), 물리 기반 파편, 차량의 관성 계산.
- **주의점**: 코너링 시 원심력 때문에 곡선 트랙의 접선 방향(벽)을 가리키므로, 미사일 궤적용으로는 절대 사용 금지.
