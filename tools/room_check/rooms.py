"""Ballistics-only check of the Chapter 1 room designs (docs/ROOMS_CH1.md).
Sweeps every pull on each vine, finds the first thing the drop touches, and labels it.
Nothing after landing is simulated except ceiling drips and wall-glide drop-offs (straight falls)."""
import numpy as np, math, sys

G = 550.0 * 1.15; DT = 1 / 60; SUB = 6; R = 12.0; WELL_R = 48.0
DECAY = math.exp(-0.22 * DT) * (1 - 0.08 * DT)
MAXS, MULT, MASS, MINIMP, SAG, SEAT = 220.0, 5.5, 0.65, 120.0, 26.0, 26.0


def launch(mid, pull):
    pull = np.asarray(pull, float)
    n = np.linalg.norm(pull, axis=-1, keepdims=True)
    v = -pull / n * np.maximum(n * MULT, MINIMP) / MASS
    p = np.asarray(mid, float) + (pull + [0, SAG]) / 2 + [0, -SEAT]
    return p, v


def segs(polys):
    out = []
    for name, pts in polys.items():
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            out.append((name, a, b))
    return out


def fly(p, v, room, tmax=4.0, skip_wells=False):
    """Vectorised flight. Returns per-drop dict of first event."""
    S = room['segs']; A = np.array([s[1] for s in S], float); B = np.array([s[2] for s in S], float)
    AB = B - A; L2 = (AB ** 2).sum(1)
    wells = np.array(room['wells'], float)
    N = len(p); res = [None] * N; active = np.arange(N)
    p = p.copy(); v = v.copy(); t = 0.0
    vine2 = room.get('catch')
    while len(active) and t < tmax:
        v[active, 1] += G * DT; v[active] *= DECAY
        p0 = p[active].copy(); p1 = p0 + v[active] * DT
        done = np.zeros(len(active), bool)
        for k in range(1, SUB + 1):
            q = p0 + (p1 - p0) * (k / SUB)
            live = ~done
            if not live.any():
                break
            qa = q[live]; idx = np.nonzero(live)[0]
            # wells
            if not skip_wells:
                d = np.linalg.norm(qa[:, None, :] - wells[None], axis=2)
                hitw = d.min(1) < WELL_R + R
                for j in np.nonzero(hitw)[0]:
                    gi = active[idx[j]]
                    res[gi] = dict(kind='well', well=int(d[j].argmin()), pos=qa[j].copy(), t=t, vel=v[gi].copy())
                    done[idx[j]] = True
            # vine catch (room 4): centre crosses the rest curve moving down, inside span
            if vine2 is not None:
                (x0, x1, y0, sag) = vine2
                live2 = ~done[idx]
                for j in np.nonzero(live2)[0]:
                    gi = active[idx[j]]
                    x, y = qa[j]
                    if x0 - 16 <= x <= x1 + 16 and v[gi, 1] > 0:
                        u = min(max((x - x0) / (x1 - x0), 0), 1)
                        yc = y0 + 2 * u * (1 - u) * sag
                        if y >= yc - 8 and y - v[gi, 1] * DT / SUB <= yc + 10:
                            res[gi] = dict(kind='vine2', pos=qa[j].copy(), t=t, vel=v[gi].copy())
                            done[idx[j]] = True
            live = ~done
            if not live.any():
                break
            qa = q[live]; idx = np.nonzero(live)[0]
            AP = qa[:, None, :] - A[None]
            tt = np.clip((AP * AB[None]).sum(2) / L2[None], 0, 1)
            C = A[None] + tt[..., None] * AB[None]
            dd = np.linalg.norm(qa[:, None, :] - C, axis=2)
            m = dd.min(1) < R
            for j in np.nonzero(m)[0]:
                si = int(dd[j].argmin()); gi = active[idx[j]]
                c = C[j, si]; nrm = (qa[j] - c) / max(dd[j, si], 1e-6)
                vn = float(-(v[gi] @ nrm))
                res[gi] = dict(kind='rock', poly=S[si][0], seg=si, pos=qa[j].copy(), contact=c.copy(),
                               n=nrm, vn=vn, t=t, vel=v[gi].copy())
                done[idx[j]] = True
        out = (p1[:, 0] < -20) | (p1[:, 0] > 1300) | (p1[:, 1] > 720) | (p1[:, 1] < -200)
        for j in np.nonzero(out & ~done)[0]:
            res[active[j]] = dict(kind='out', pos=p1[j].copy(), t=t); done[j] = True
        p[active] = p1; active = active[~done]; t += DT
    for i in range(N):
        if res[i] is None:
            res[i] = dict(kind='timeout', pos=p[i].copy(), t=t)
    return res


def surface(n):
    up = -n[1]
    if up > 0.82: return 'floor'
    if up < -0.82: return 'ceiling'
    if abs(n[0]) > 0.97: return 'wall'
    return 'slope' if up > 0 else 'overhang'


def regime(vn):
    return 'squash' if vn < 70 else 'film' if vn < 160 else 'film+2' if vn < 520 else 'split+5'


def drip(room, x, y):
    return fly(np.array([[x, y]]), np.array([[0.0, 90.0]]), room)[0]


def sweep(room, mid, label_fn, angles=np.arange(2, 179, 1.5), stretches=np.arange(10, MAXS + 1, 5)):
    A, S = np.meshgrid(np.radians(angles), stretches, indexing='ij')
    pulls = np.stack([np.cos(A) * S, np.sin(A) * S], -1).reshape(-1, 2)
    p, v = launch(mid, pulls)
    res = fly(p, v, room)
    labels = [label_fn(r) for r in res]
    return pulls, labels, res


def report(name, pulls, labels, res, want):
    from collections import Counter
    c = Counter(labels); N = len(labels)
    print(f'\n== {name}: {N} pulls')
    for k, n in c.most_common():
        print(f'   {k:<34} {100*n/N:5.1f}%')
    ok = [i for i, l in enumerate(labels) if l in want]
    if ok:
        ang = np.degrees(np.arctan2(pulls[ok, 1], pulls[ok, 0])); st = np.linalg.norm(pulls[ok], axis=1)
        print(f'   intended window: pull angle {ang.min():.0f}..{ang.max():.0f} deg, stretch {st.min():.0f}..{st.max():.0f}')
    return ok


def show(room, mid, pull, label_fn, tag=''):
    p, v = launch(mid, [pull])
    r = fly(p, v, room)[0]
    s = f'   pull {pull} -> launch ({p[0,0]:.0f},{p[0,1]:.0f}) v=({v[0,0]:.0f},{v[0,1]:.0f}) |v|={np.linalg.norm(v[0]):.0f}'
    if r['kind'] == 'rock':
        s += f"; hits {r['poly']} at ({r['pos'][0]:.0f},{r['pos'][1]:.0f}) [{surface(r['n'])}] vn={r['vn']:.0f} ({regime(r['vn'])}) t={r['t']:.2f}s"
    else:
        s += f"; {r['kind']} at ({r['pos'][0]:.0f},{r['pos'][1]:.0f}) t={r['t']:.2f}s"
    print(s + f' => {label_fn(r)} {tag}')
    return r


def mkroom(polys, wells, catch=None):
    return dict(segs=segs(polys), wells=wells, catch=catch)


def roof(tooth_x):
    return [(0, 0), (1280, 0), (1280, 110), (tooth_x + 20, 110), (tooth_x, 147), (tooth_x - 20, 110), (0, 110)]


ROOMS = {}

# ---------- 1 The First Drop (Level 0 as built, approximated) ----------
r1 = mkroom({'roof': [(0, 0), (1280, 0), (1280, 78), (980, 96), (760, 54), (520, 110), (340, 48), (180, 92), (0, 64)],
             'tooth': [(240, 0), (310, 0), (280, 140), (275, 155), (270, 140)],
             'basin': [(220, 680), (230, 620), (320, 620), (330, 680)],
             'pillar': [(480, 720), (500, 500), (512, 484), (528, 484), (540, 500), (560, 720)],
             'platform': [(860, 720), (880, 620), (1120, 620), (1140, 720)],
             'floorkill': [(0, 760), (1280, 760), (1280, 800), (0, 800)]}, [(1000, 460)])
def l1(r):
    if r['kind'] == 'well': return 'WELL direct'
    if r['kind'] != 'rock': return 'miss: ' + r['kind']
    return f"miss: {r['poly']} {surface(r['n'])}"
ROOMS[1] = (r1, (275, 400), l1, {'WELL direct'}, [(-70, 110)])

# ---------- 2 The Wall ----------
F2 = 1020
r2 = mkroom({'roof': roof(300), 'lwall': [(0, 110), (30, 110), (30, 720), (0, 720)],
             'gallery': [(30, 400), (1006, 400), (1006, 425), (890, 425), (890, 600), (1100, 600), (1100, 720), (30, 720)],
             'mass': [(F2, 110), (1280, 110), (1280, 720), (1100, 720), (1100, 445), (F2, 445)]},
            [(1004, 520)])
def l2(r):
    if r['kind'] == 'well': return 'WELL direct'
    if r['kind'] != 'rock': return 'miss: ' + r['kind']
    s = surface(r['n'])
    if r['poly'] == 'mass' and s == 'wall' and r['n'][0] < 0 and 110 <= r['contact'][1] <= 445:
        return 'GLIDE face' if r['vn'] >= 70 else 'miss: face squash'
    if s == 'ceiling':
        d = drip(r2, r['pos'][0], r['contact'][1] + 18)
        return 'drip->well' if d['kind'] == 'well' else f'miss: ceiling drip'
    return f"miss: {r['poly']} {s}"
ROOMS[2] = (r2, (300, 260), l2, {'GLIDE face'}, [(-150, 40), (-200, 30), (-120, 70)])

# ---------- 3 The Roof ----------
r3 = mkroom({'roof': [(0, 0), (1280, 0), (1280, 200), (560, 200), (560, 110), (260, 110), (240, 147), (220, 110), (0, 110)],
             'lwall': [(0, 110), (30, 110), (30, 720), (0, 720)],
             'floor': [(30, 650), (640, 650), (640, 720), (30, 720)],
             'plateau_l': [(640, 430), (920, 430), (920, 460), (700, 460), (700, 720), (640, 720)],
             'plateau_r': [(1000, 430), (1250, 430), (1250, 720), (700, 720), (700, 660), (1220, 660), (1220, 460), (1000, 460)],
             'rwall': [(1250, 110), (1280, 110), (1280, 720), (1250, 720)]}, [(960, 610)])
def l3(r):
    if r['kind'] == 'well': return 'WELL direct'
    if r['kind'] != 'rock': return 'miss: ' + r['kind']
    s = surface(r['n']); x, y = r['contact']
    if s == 'ceiling' and r['vn'] >= 70:
        d = drip(r3, r['pos'][0], y + 18)
        return 'DRIP->well' if d['kind'] == 'well' else 'miss: ceiling drip lands ' + (d.get('poly') or d['kind'])
    if s == 'wall' and y > 430 and 920 <= x <= 1000:
        return 'hole lip glide->well'
    if y > 460 and 700 < x < 1220:
        return 'miss: inside chamber'
    return f"miss: {r['poly']} {s}"
ROOMS[3] = (r3, (240, 450), l3, {'DRIP->well'}, [(-200, 90), (-190, 95)])

# ---------- 4 The Vein (two vines) ----------
O4 = {'roof': roof(230), 'lwall': [(0, 110), (30, 110), (30, 720), (0, 720)],
      'floor': [(30, 650), (1250, 650), (1250, 720), (30, 720)],
      'overhang': [(760, 110), (1250, 110), (1250, 330), (975, 330), (975, 140), (865, 140), (865, 330), (760, 330)],
      'rwall': [(1250, 110), (1280, 110), (1280, 720), (1250, 720)]}
V2 = (835, 1005, 480, SAG)
r4 = mkroom(O4, [(920, 205)], catch=V2)
r4b = mkroom(O4, [(920, 205)])
def l4(r):
    if r['kind'] == 'well': return 'WELL direct (from vine 1)'
    if r['kind'] == 'vine2': return 'ON VINE 2'
    if r['kind'] != 'rock': return 'miss: ' + r['kind']
    s = surface(r['n'])
    if s == 'ceiling' and r['vn'] >= 70:
        x = r['pos'][0]
        return 'underside drip->vine 2' if V2[0] - 16 <= x <= V2[1] + 16 else 'miss: underside drip'
    return f"miss: {r['poly']} {s}"
def l4b(r):
    if r['kind'] == 'well': return 'WELL (from vine 2)'
    if r['kind'] != 'rock': return 'miss: ' + r['kind']
    s = surface(r['n']); x = r['pos'][0]
    if s in ('wall',) and 140 <= r['contact'][1] <= 330 and 865 <= r['contact'][0] <= 975:
        return 'chimney wall: glides out, falls on vine 2'
    if s == 'ceiling' and V2[0] - 16 <= x <= V2[1] + 16:
        return 'underside drip->vine 2 (retry)'
    return f"miss: {r['poly']} {s}"
ROOMS[4] = (r4, (230, 470), l4, {'ON VINE 2', 'underside drip->vine 2'}, [(-170, 25), (-200, 20)])

# ---------- 5 The Lip ----------
r5 = mkroom({'roof': roof(230), 'lwall': [(0, 110), (30, 110), (30, 720), (0, 720)],
             'floor': [(30, 650), (560, 650), (560, 720), (30, 720)],
             'block': [(560, 300), (860, 300), (860, 500), (720, 500), (720, 610), (870, 610), (1100, 520), (1200, 575),
                       (1250, 575), (1250, 720), (560, 720)],
             'rwall': [(1250, 110), (1280, 110), (1280, 720), (1250, 720)]}, [(785, 556)])
def l5(r):
    if r['kind'] == 'well': return 'WELL direct'
    if r['kind'] != 'rock': return 'miss: ' + r['kind']
    s = surface(r['n']); x, y = r['contact']
    if r['poly'] == 'block' and 870 <= x < 1100 and y > 515 and r['n'][0] < 0:
        return 'SLOPE->rolls to well'
    if r['poly'] == 'block' and 1100 <= x <= 1250 and y > 515:
        return 'miss: past the lip, gutter'
    if r['poly'] == 'rwall':
        return 'miss: right wall glide to gutter'
    if s == 'ceiling':
        return 'miss: roof drip'
    return f"miss: {r['poly']} {s}"
ROOMS[5] = (r5, (230, 430), l5, {'SLOPE->rolls to well'}, [(-110, 140), (-130, 150)])

# ---------- 6 The Thread ----------
r6 = mkroom({'roof': roof(230), 'lwall': [(0, 110), (30, 110), (30, 720), (0, 720)],
             'floor': [(30, 650), (1250, 650), (1250, 720), (30, 720)],
             'anvil': [(610, 450), (670, 450), (700, 480), (700, 650), (580, 650), (580, 480)],
             'rwall': [(1250, 110), (1280, 110), (1280, 720), (1250, 720)]}, [(520, 595), (760, 595)])
def drip6(x, y):
    d = fly(np.array([[x, y]]), np.array([[0.0, 90.0]]), r6, skip_wells=True)[0]
    return d
def l6(r):
    if r['kind'] == 'well': return f"miss: one pod direct (pod {r['well']}) - closes again"
    if r['kind'] != 'rock': return 'miss: ' + r['kind']
    s = surface(r['n']); x, y = r['contact']
    if s == 'ceiling' and r['vn'] >= 70:
        d = drip6(r['pos'][0], y + 18)
        if d['kind'] == 'rock' and d['poly'] == 'anvil' and surface(d['n']) == 'floor':
            return 'DRIP->anvil SPLIT' if d['vn'] >= 520 else 'miss: drip too soft'
        return 'miss: roof drip misses anvil'
    if r['poly'] == 'anvil' and s == 'floor':
        vt = abs(r['vel'][0])
        return 'miss: anvil hit, lopsided' if r['vn'] >= 520 else 'miss: anvil hit, soft'
    return f"miss: {r['poly']} {s}"
ROOMS[6] = (r6, (230, 450), l6, {'DRIP->anvil SPLIT'}, [(-200, 60)])

# ---------- 7 The Shelf (hidden) ----------
r7 = mkroom({'roof': roof(230), 'lwall': [(0, 110), (30, 110), (30, 720), (0, 720)],
             'floor': [(30, 650), (620, 650), (620, 720), (30, 720)],
             'block': [(620, 330), (900, 330), (900, 470), (760, 470), (760, 580), (900, 580), (900, 720), (620, 720)],
             'shelf': [(900, 580), (1060, 515), (1060, 531), (900, 596)],
             'pitfloor': [(900, 680), (1250, 680), (1250, 720), (900, 720)],
             'rwall': [(1250, 110), (1280, 110), (1280, 720), (1250, 720)]}, [(828, 525)])
def l7(r):
    if r['kind'] == 'well': return 'WELL direct'
    if r['kind'] != 'rock': return 'miss: ' + r['kind']
    s = surface(r['n'])
    if r['poly'] == 'shelf' and r['n'][1] < 0: return 'SHELF->rolls to well'
    if r['poly'] == 'rwall': return 'miss: right wall glide to pit floor'
    return f"miss: {r['poly']} {s}"
ROOMS[7] = (r7, (230, 430), l7, {'SHELF->rolls to well'}, [(-120, 150)])

# ---------- 8 The Dark ----------
F8 = 920
r8 = mkroom({'roof': roof(200), 'lwall': [(0, 110), (30, 110), (30, 720), (0, 720)],
             'floor': [(30, 650), (420, 650), (420, 720), (30, 720)],
             'ridge': [(420, 650), (520, 320), (560, 320), (640, 650), (640, 720), (420, 720)],
             'gallery': [(640, 470), (906, 470), (906, 495), (800, 495), (800, 650), (1100, 650), (1100, 720), (640, 720)],
             'mass': [(820, 110), (1280, 110), (1280, 720), (1100, 720), (1100, 535), (F8, 535), (F8, 300), (820, 300)]},
            [(904, 610)])
def l8(r):
    if r['kind'] == 'well': return 'WELL direct'
    if r['kind'] != 'rock': return 'miss: ' + r['kind']
    s = surface(r['n'])
    if r['poly'] == 'mass' and s == 'wall' and r['n'][0] < 0 and 300 <= r['contact'][1] <= 535:
        return 'GLIDE face' if r['vn'] >= 70 else 'miss: face squash'
    return f"miss: {r['poly']} {s}"
ROOMS[8] = (r8, (200, 420), l8, {'GLIDE face'}, [(-190, 110)])

if __name__ == '__main__':
    which = [int(a) for a in sys.argv[1:]] or list(ROOMS)
    for k in which:
        room, mid, fn, want, picks = ROOMS[k]
        pulls, labels, res = sweep(room, mid, fn)
        ok = report(f'room {k}', pulls, labels, res, want)
        for pk in picks:
            show(room, mid, pk, fn)
        if k == 4:
            print('   vine 2 throws:')
            for pk in [(0, 150), (0, 100), (12, 150), (-12, 150), (25, 150), (0, 40)]:
                show(r4b, (920, 480), pk, l4b)
            p2, lb2, rs2 = sweep(r4b, (920, 480), l4b)
            report('room 4, vine 2', p2, lb2, rs2, {'WELL (from vine 2)'})


def face_hist(room, mid, fn, lab='GLIDE face'):
    pulls, labels, res = sweep(room, mid, fn)
    ys = np.array([r['contact'][1] for r, l in zip(res, labels) if l == lab])
    vns = np.array([r['vn'] for r, l in zip(res, labels) if l == lab])
    if len(ys):
        print('   face impact y: ' + ' '.join(f'{int(a)}-{int(a)+50}:{int(((ys>=a)&(ys<a+50)).sum())}' for a in range(100, 450, 50)))
        print(f'   vn on face: <520: {(vns<520).mean()*100:.0f}%  ;  160-519: {((vns>=160)&(vns<520)).mean()*100:.0f}%')
