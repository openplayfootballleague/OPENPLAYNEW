import { describe, expect, it } from "vitest";
import { buildStandings } from "./standings";

describe("Open Play league standings", () => {
  it("shares positions for teams level on points regardless of goal difference", () => {
    const rows=buildStandings([{id:"alpha",name:"Alpha"},{id:"bravo",name:"Bravo"},{id:"charlie",name:"Charlie"}],
      [{id:"f1",home_team_id:"alpha",away_team_id:"charlie"},{id:"f2",home_team_id:"bravo",away_team_id:"charlie"}],
      [{fixture_id:"f1",home_score:5,away_score:0},{fixture_id:"f2",home_score:1,away_score:0}]);
    expect(rows.map(({id,position,points})=>({id,position,points}))).toEqual([
      {id:"alpha",position:1,points:3},{id:"bravo",position:1,points:3},{id:"charlie",position:3,points:0},
    ]);
    expect(rows[0].for-rows[0].against).toBeGreaterThan(rows[1].for-rows[1].against);
  });
  it("leaves a ranking gap after teams share a position", () => {
    const rows=buildStandings([{id:"a",name:"A"},{id:"b",name:"B"},{id:"c",name:"C"},{id:"d",name:"D"}],
      [{id:"a1",home_team_id:"a",away_team_id:"d"},{id:"b1",home_team_id:"b",away_team_id:"d"},{id:"c1",home_team_id:"c",away_team_id:"d"}],
      [{fixture_id:"a1",home_score:1,away_score:0},{fixture_id:"b1",home_score:2,away_score:0},{fixture_id:"c1",home_score:3,away_score:0}]);
    expect(rows.map(({id,position})=>[id,position])).toEqual([["a",1],["b",1],["c",1],["d",4]]);
  });
  it("does not count fixtures without a result", () => {
    const rows=buildStandings([{id:"a",name:"A"},{id:"b",name:"B"}],[{id:"f1",home_team_id:"a",away_team_id:"b"}],[]);
    expect(rows.map(({played,points})=>[played,points])).toEqual([[0,0],[0,0]]);
  });
});
