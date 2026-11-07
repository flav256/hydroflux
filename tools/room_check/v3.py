import numpy as np, rooms as R, v2
LW = [(0,110),(30,110),(30,720),(0,720)]; RW = [(1250,110),(1280,110),(1280,720),(1250,720)]
def mk5(bt=400, bx=(560,760), px=640, slope_end=(1060,500), vine=(230,430)):
    b0, b1 = bx; sx, sy = slope_end
    well = ((px + b1) / 2, 556)
    room = R.mkroom({'roof': R.roof(vine[0]), 'lwall': LW, 'rwall': RW, 'floor': [(30,650),(b0,650),(b0,720),(30,720)],
        'block': [(b0,bt),(b1,bt),(b1,500),(px,500),(px,610),(b1+10,610),(sx,sy),(sx+110,sy+55),(1250,sy+55),(1250,720),(b0,720)]}, [well])
    def lab(r):
        if r['kind'] == 'well': return 'WELL direct'
        if r['kind'] != 'rock': return 'miss: ' + r['kind']
        s = R.surface(r['n']); x, y = r['contact']
        if r['poly'] == 'block' and b1 + 10 <= x < sx and y > sy - 5 and r['n'][0] < 0: return 'SLOPE->rolls to well'
        if r['poly'] == 'block' and x >= sx and y > sy - 5: return 'miss: past the lip'
        if r['poly'] == 'rwall': return 'miss: right wall to gutter'
        if s == 'ceiling': return 'miss: roof drip'
        return f"miss: {r['poly']} {s}"
    return room, vine, lab, well
def mk7(bt=400, bx=(600,820), px=690, shelf_end=(1040,500), vine=(230,430)):
    b0, b1 = bx; sx, sy = shelf_end
    well = ((px + b1) / 2, 535)
    room = R.mkroom({'roof': R.roof(vine[0]), 'lwall': LW, 'rwall': RW, 'floor': [(30,650),(b0,650),(b0,720),(30,720)],
        'block': [(b0,bt),(b1,bt),(b1,480),(px,480),(px,590),(b1,590),(b1,720),(b0,720)],
        'shelf': [(b1,590),(sx,sy),(sx,sy+16),(b1,606)], 'pitfloor': [(b1,680),(1250,680),(1250,720),(b1,720)]}, [well])
    def lab(r):
        if r['kind'] == 'well': return 'WELL direct'
        if r['kind'] != 'rock': return 'miss: ' + r['kind']
        s = R.surface(r['n'])
        if r['poly'] == 'shelf' and r['n'][1] < 0: return 'SHELF->rolls to well'
        if r['poly'] == 'rwall': return 'miss: right wall to pit floor'
        if r['poly'] == 'pitfloor': return 'miss: pit floor'
        return f"miss: {r['poly']} {s}"
    return room, vine, lab, well
def mk8(ridge_top=400, lip=870, face_top=250, vine=(200,420)):
    F = 920
    room = R.mkroom({'roof': R.roof(vine[0]), 'lwall': LW, 'floor': [(30,650),(420,650),(420,720),(30,720)],
        'ridge': [(420,650),(510,ridge_top),(550,ridge_top),(640,650),(640,720),(420,720)],
        'gallery': [(640,470),(906,470),(906,495),(800,495),(800,650),(1100,650),(1100,720),(640,720)],
        'mass': [(lip,110),(1280,110),(1280,720),(1100,720),(1100,535),(F,535),(F,face_top),(lip,face_top)]}, [(904,610)])
    def lab(r):
        if r['kind'] == 'well': return 'WELL direct'
        if r['kind'] != 'rock': return 'miss: ' + r['kind']
        s = R.surface(r['n'])
        if r['poly'] == 'mass' and s == 'wall' and r['n'][0] < 0 and face_top <= r['contact'][1] <= 535 and r['contact'][0] >= F - 1:
            return 'GLIDE face' if r['vn'] >= 70 else 'miss: face squash'
        return f"miss: {r['poly']} {s}"
    return room, vine, lab, (904, 610)
def run(name, mk, want, **kw):
    room, vine, lab, well = mk(**kw); p, l, r = R.sweep(room, vine, lab)
    ok = [i for i, x in enumerate(l) if x in want]
    top = {k: f'{100*l.count(k)/len(l):.1f}%' for k in sorted(set(l)) if l.count(k)/len(l) > 0.004 or k in want or 'direct' in k}
    print(name, kw, top)
    if ok:
        ang = np.degrees(np.arctan2(p[ok,1], p[ok,0])); st = np.linalg.norm(p[ok], axis=1)
        print('   window angle %.0f..%.0f stretch %.0f..%.0f' % (ang.min(), ang.max(), st.min(), st.max()))
        b = v2.best(p, l, want); R.show(room, vine, b, lab, '(median pick)')
    return p, l, r
if __name__ == '__main__':
    run('r5', mk5, {'SLOPE->rolls to well'})
    run('r5', mk5, {'SLOPE->rolls to well'}, bt=440)
    run('r7', mk7, {'SHELF->rolls to well'})
    run('r7', mk7, {'SHELF->rolls to well'}, bt=440)
    run('r8', mk8, {'GLIDE face'})
    run('r8', mk8, {'GLIDE face'}, ridge_top=430, face_top=200)
