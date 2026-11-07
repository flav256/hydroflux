"""Final Chapter 1 ballistics check (docs/ROOMS_CH1.md). Usage: python3 ch1_check.py [radius]"""
import sys, numpy as np, rooms as R, v2, v3
if len(sys.argv) > 1: R.R = float(sys.argv[1])
LW, RW = v3.LW, v3.RW

def room2(lipx=1020, ft=110):
    room = R.mkroom({'roof': R.roof(300), 'lwall': LW,
        'gallery': [(30,400),(1006,400),(1006,425),(890,425),(890,600),(1100,600),(1100,720),(30,720)],
        'mass': [(lipx,110),(1280,110),(1280,720),(1100,720),(1100,445),(1020,445),(1020,ft),(lipx,ft)]}, [(1004,520)])
    def lab(r):
        if r['kind'] == 'well': return 'WELL direct'
        if r['kind'] != 'rock': return 'miss: ' + r['kind']
        s = R.surface(r['n'])
        if r['poly'] == 'mass' and s == 'wall' and r['n'][0] < 0 and r['contact'][0] >= 1019 and ft <= r['contact'][1] <= 445:
            return 'GLIDE face' if r['vn'] >= 70 else 'miss: face squash'
        if s == 'ceiling': return 'miss: roof drip onto gallery'
        return f"miss: {r['poly']} {s}"
    return room, (300, 260), lab, (1004, 520)

def room6():
    a0, a1, ty, fl = 600, 700, 600, 680
    room = R.mkroom({'roof': R.roof(250), 'lwall': LW, 'rwall': RW, 'ledge': [(30,380),(400,380),(400,720),(30,720)],
        'floor': [(400,fl),(1250,fl),(1250,720),(400,720)],
        'anvil': [(a0,ty),(a1,ty),(a1+20,ty+20),(a1+20,fl),(a0-20,fl),(a0-20,ty+20)]}, [(560,632),(850,632)])
    def lab(r):
        if r['kind'] == 'well': return 'miss: one pod direct (closes again)'
        if r['kind'] != 'rock': return 'miss: ' + r['kind']
        s = R.surface(r['n'])
        if r['poly'] == 'anvil' and s == 'floor':
            if r['vn'] < 520: return 'miss: anvil, soft (film stays)'
            if abs(r['vel'][0]) >= v2.K_SPLIT * r['vn']: return 'miss: anvil, lopsided split'
            return 'SPLIT both ways'
        return f"miss: {r['poly']} {s}"
    def halves(r, pod_y=632):
        out = []
        for sgn in (-1, 1):
            u = r['vel'][0] + sgn * v2.K_SPLIT * r['vn']
            x = (a1 + 8.5) if u > 0 else (a0 - 8.5); y = ty - 8.5; vy = 0.0
            while y < pod_y:
                vy += R.G * R.DT; x += u * R.DT; y += vy * R.DT; u *= R.DECAY; vy *= R.DECAY
            out.append(x)
        return out
    return room, (250, 240), lab, halves

def summary(name, room, vine, lab, want, extra=None):
    p, l, r = R.sweep(room, vine, lab)
    ok = [i for i, x in enumerate(l) if x in want]
    N = len(l); share = 100 * len(ok) / N
    direct = 100 * sum('direct' in x for x in l) / N
    misses = sorted({x for x in l if x.startswith('miss')}, key=lambda k: -l.count(k))[:4]
    line = f'{name}: intended {share:.1f}%  direct {direct:.1f}%'
    if ok:
        ang = np.degrees(np.arctan2(p[ok,1], p[ok,0])); st = np.linalg.norm(p[ok], axis=1)
        line += f'  window {ang.min():.0f}..{ang.max():.0f} deg x {st.min():.0f}..{st.max():.0f} px'
    print(line)
    print('   top misses: ' + '; '.join(f'{m[6:]} {100*l.count(m)/N:.1f}%' for m in misses))
    if ok:
        b = v2.best(p, l, want); rr = R.show(room, vine, b, lab, '(pick)')
        if extra: extra(p, l, r, ok, rr)
    return p, l, r

if __name__ == '__main__':
    print(f'radius {R.R}')
    R1 = R.ROOMS[1]; summary('1 First Drop', R1[0], R1[1], R1[2], R1[3])
    R.show(R1[0], R1[1], (-70, 110), R1[2], '(LightProbe default pull)')
    for lipx, ft in [(960, 260)]:
        room, vine, lab, _ = room2(lipx, ft)
        summary(f'2 Wall lip x{lipx} y{ft}', room, vine, lab, {'GLIDE face'},
                lambda p, l, r, ok, rr: print('   face impact y p10/p50/p90: %d/%d/%d -> glide to 445' %
                                              tuple(np.percentile([r[i]['contact'][1] for i in ok], [10, 50, 90]))))
    room, vine, lab = v2.mk3(wt=320, well=(720, 590)); summary('3 Roof', room, vine, lab, {'DRIP->well'})
    R4 = R.ROOMS[4]; summary('4 Vein, vine 1', R4[0], R4[1], R4[2], {'ON VINE 2', 'underside drip->vine 2'})
    summary('4 Vein, vine 2', R.r4b, (920, 480), R.l4b, {'WELL (from vine 2)'})
    room, vine, lab, _ = v3.mk5(bt=440); summary('5 Lip', room, vine, lab, {'SLOPE->rolls to well'})
    room, vine, lab, halves = room6()
    def pods(p, l, r, ok, rr):
        hx = np.array([halves(r[i]) for i in ok])
        inside = ((np.abs(hx[:, 0] - 560) < 56.5) & (np.abs(hx[:, 1] - 850) < 56.5)).mean()
        print('   halves x at pod height p10..p90: left %d..%d right %d..%d; both in pods: %.0f%% of splits' %
              (*np.percentile(hx[:, 0], [10, 90]), *np.percentile(hx[:, 1], [10, 90]), 100 * inside))
        print('   pick halves land at', [round(v) for v in halves(rr)])
    summary('6 Thread', room, vine, lab, {'SPLIT both ways'}, pods)
    room, vine, lab, _ = v3.mk7(bt=440); summary('7 Shelf', room, vine, lab, {'SHELF->rolls to well'})
    room, vine, lab, _ = v3.mk8(); summary('8 Dark', room, vine, lab, {'GLIDE face'},
        lambda p, l, r, ok, rr: print('   face impact y p10/p50/p90: %d/%d/%d -> glide to 535' %
                                      tuple(np.percentile([r[i]['contact'][1] for i in ok], [10, 50, 90]))))
