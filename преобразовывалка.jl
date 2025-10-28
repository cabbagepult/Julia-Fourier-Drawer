using Luxor
using Luxor.Colors
using LightXML
using DelimitedFiles
using QuadGK
using LightXML

function extract_first_path_d(svg_file)
    xdoc = parse_file(svg_file)
    xroot = root(xdoc)
    first_path = find_element(xroot, "path")
    
    if first_path ≠ nothing
        d_attr = attribute(first_path, "d")
        return d_attr
    else
        return nothing
    end
end
function p(x,y) return Point(x,y) end
Base.abs(p::Point) = sqrt(p[1]^2+p[2]^2)
function Lerp(x,y,ratio=0.5)
    return x+(y-x)*ratio
end
function get_curve_value(curve1,t)
    return Lerp(Lerp(Lerp(curve1[1],curve1[2],t),Lerp(curve1[2],curve1[3],t),t),Lerp(Lerp(curve1[2],curve1[3],t),Lerp(curve1[3],curve1[4],t),t),t)
end
function draw_Bézier_curve(curve1,step=0.01,point_size=10)
for t in 0:step:(1-step)
        dot1=get_curve_value(curve1,t)
        dot2=get_curve_value(curve1,t+step)
        line(dot1,dot2,action=:stroke)
    end
    for d in curve1 circle(d, point_size, action = :fill) end
end
function split_Bézier_curve(curve1,split_value)
    curve2=[curve1[1],0,0,get_curve_value(curve1,split_value)]
    curve3=[get_curve_value(curve1,split_value),0,0,curve1[4]]
    curve2[2]=(1-split_value)*curve1[1]+split_value*curve1[2]
    curve2[3]=(1-split_value)^2*curve1[1]+2*(1-split_value)*split_value*curve1[2]+split_value^2*curve1[3]
    curve3[3]=(split_value)*curve1[4]+(1-split_value)*curve1[3]
    curve3[2]=(split_value)^2*curve1[4]+2*(1-split_value)*split_value*curve1[3]+(1-split_value)^2*curve1[2]
    return [curve2,curve3]
end
function split_Bézier_curve_for_closed_path(curve1,split_value)
    v1=(1-split_value)*curve1[1]+split_value*curve1[2]
    v2=(1-split_value)^2*curve1[1]+2*(1-split_value)*split_value*curve1[2]+split_value^2*curve1[3]
    v4=(split_value)*curve1[4]+(1-split_value)*curve1[3]
    v3=(split_value)^2*curve1[4]+2*(1-split_value)*split_value*curve1[3]+(1-split_value)^2*curve1[2]
    return (v1,v2,v3,v4)
end
struct closed_path
    size::Int
    curves::Array{Tuple{Point,Point,Point}}
end
function draw_closed_path(путь::closed_path,step=0.01,point_size=10)
    if путь.size<1 return Nothing end
    x=[путь.curves[end][end]]
    append!(x,путь.curves[1])
    draw_Bézier_curve(x,step,point_size)
    for ind in 2:путь.size
    x=[путь.curves[ind-1][3]]
    append!(x,путь.curves[ind])
    draw_Bézier_curve(x,step,point_size)
    end
    return Nothing
end
function split_closed_path(путь::closed_path,t,type=0)
    if type==0 t*=путь.size  end
    кривая=Int(floor(t)%путь.size+1)
    t%=1
    if t<0.001 return closed_path(путь.size,append!(путь.curves[кривая:end],путь.curves[1:кривая-1]))  end
    v1,v2,v3,v4=split_Bézier_curve_for_closed_path(append!([путь.curves[(путь.size+кривая-2)%путь.size+1][end]],путь.curves[кривая]),t)
    кривая1=(путь.curves[кривая][1],v1,v2)
    кривая2=(v3,v4,путь.curves[кривая][end])
    return closed_path(путь.size+1,append!([кривая2],путь.curves[кривая+1:end],путь.curves[1:кривая-1],[кривая1]))
end
function close_path(путь::closed_path,first_path_point::Point)
    if abs(путь.curves[end][end]-first_path_point)<0.01
        return closed_path(путь.size,push!(путь.curves[1:end-1],(путь.curves[end][1],путь.curves[end][2],first_path_point))) end
    reversed_path=[]
    for i in путь.size:-1:2
        push!(reversed_path,(путь.curves[i][2],путь.curves[i][1],путь.curves[i-1][3]))
    end
    push!(reversed_path,(путь.curves[1][2],путь.curves[1][1],first_path_point))
    return closed_path(путь.size*2,append!(путь.curves,reversed_path))
end
function parse_dot(s)
    t=split(s,",")
    x=Meta.parse(t[1])
    y=Meta.parse(t[2])
    return p(x,y)
end
function read_d_string(d::String)
    first_path_point=p(0,0)
    last_z_point=p(0,0)
    current_pos=p(0,0)
    curves=[]
    all_paths=[]
    commands=["m","M","c","C","l","L","v","V","h","H","z","Z"]
    for x in commands d=replace(d,x=>x*" ") end
    d=replace(d,","=>" ")
    for i in 1:10 d=replace(d,"  "=>" ") end
    while d[end]==" " d=chop(d) end
    d=split(d," ")
    k=1
    last_command=""
    while k<=length(d)
        #println(k," ",d[k])
        if isnothing(d[k]) k+=1; continue end
        smth_done=false
        if d[k]=="m"
            if length(curves)>0
                push!(all_paths,close_path(closed_path(length(curves),curves),first_path_point))
            else
                last_z_point+=p(Meta.parse(d[k+1]),Meta.parse(d[k+2]))
            end
            current_pos+=p(Meta.parse(d[k+1]),Meta.parse(d[k+2]))
            first_path_point=current_pos
            curves=[]
            k+=2
            last_command="m"
            smth_done=true
        end
        if d[k]=="M"
            if length(curves)>0
                push!(all_paths,close_path(closed_path(length(curves),curves),first_path_point))
            else
                last_z_point=p(Meta.parse(d[k+1]),Meta.parse(d[k+2]))
            end
            current_pos=p(Meta.parse(d[k+1]),Meta.parse(d[k+2]))
            first_path_point=current_pos
            curves=[]
            k+=2
            last_command="M"
            smth_done=true
        end
        if d[k]=="c"
            push!(curves,(current_pos+p(Meta.parse(d[k+1]),Meta.parse(d[k+2])),current_pos+p(Meta.parse(d[k+3]),Meta.parse(d[k+4])),current_pos+p(Meta.parse(d[k+5]),Meta.parse(d[k+6]))))
            k+=6
            current_pos=curves[end][end]
            last_command="c"
            smth_done=true
        end
        if d[k]=="C"
            push!(curves,(p(Meta.parse(d[k+1]),Meta.parse(d[k+2])),p(Meta.parse(d[k+3]),Meta.parse(d[k+4])),p(Meta.parse(d[k+5]),Meta.parse(d[k+6]))))
            k+=6
            current_pos=curves[end][end]
            last_command="C"
            smth_done=true
        end
        if d[k]=="l"
            push!(curves,(current_pos,current_pos+p(Meta.parse(d[k+1]),Meta.parse(d[k+2])),current_pos+p(Meta.parse(d[k+1]),Meta.parse(d[k+2]))))
            k+=2
            current_pos=curves[end][end]
            last_command="l"
            smth_done=true
        end
        if d[k]=="L"
            push!(curves,(current_pos,p(Meta.parse(d[k+1]),Meta.parse(d[k+2])),p(Meta.parse(d[k+1]),Meta.parse(d[k+2]))))
            k+=2
            current_pos=curves[end][end]
            last_command="L"
            smth_done=true
        end
        if d[k]=="v"
            dot=p(current_pos[1],current_pos[2]+Meta.parse(d[k+1]))
            k+=1
            push!(curves,(current_pos,dot,dot))
            last_command="v"
            smth_done=true
        end
        if d[k]=="V"
            dot=p(current_pos[1],Meta.parse(d[k+1]))
            k+=1
            push!(curves,(current_pos,dot,dot))
            last_command="V"
            smth_done=true
        end
        if d[k]=="h"
            dot=p(current_pos[1]+Meta.parse(d[k+1]),current_pos[2])
            k+=1
            push!(curves,(current_pos,dot,dot))
            last_command="h"
            smth_done=true
        end
        if d[k]=="H"
            dot=p(Meta.parse(d[k+1]),current_pos[2])
            k+=1
            push!(curves,(current_pos,dot,dot))
            last_command="H"
            smth_done=true
        end
        if lowercase(d[k])=="z"
            push!(curves,(current_pos,last_z_point,last_z_point))
            current_pos=curves[end][end]
            push!(all_paths,close_path(closed_path(length(curves),curves),first_path_point))
            curves=[]
            last_z_point=current_pos
            first_path_point=current_pos
            last_command="z"
            smth_done=true
        end
        if !smth_done
            d[k-1]=last_command
            if k+1>length(d) break end
            k-=1; continue
        end
        k+=1
    end
    if length(curves)>0
        push!(all_paths,close_path(closed_path(length(curves),curves),first_path_point))
    end
    return all_paths
end
function get_point_on_closed_path(путь::closed_path, t,type=0)
    if type==0 t*=путь.size end
    кривая=Int(floor(t)%путь.size+1)
    t%=1
    первая_точка=путь.curves[(кривая-2+путь.size)%путь.size+1][end]
    return get_curve_value(append!([первая_точка],путь.curves[кривая]),t)
end


function connect_closed_paths(paths,step=0.001)
    for _ in 1:length(paths)-1
        min_length=Inf
        min_values=()
        for t1 in 0:step:1
            первая_точка=get_point_on_closed_path(paths[1],t1)
            for номер_пути in eachindex(paths[2:end]) for t2 in 0:step:1
                вторая_точка=get_point_on_closed_path(paths[номер_пути+1],t2)
                if min_length>abs(первая_точка-вторая_точка)
                    min_length=abs(первая_точка-вторая_точка)
                    min_values=(t1,номер_пути+1,t2,первая_точка,вторая_точка)
                end
            end end
        end
        новый_путь1=split_closed_path(paths[1],min_values[1])
        новый_путь2=split_closed_path(paths[min_values[2]],min_values[3])
        new_curves=append!(новый_путь1.curves,[(min_values[4],min_values[5],min_values[5])],новый_путь2.curves,[(min_values[5],min_values[4],min_values[4])])
        paths=append!(paths[2:min_values[2]-1],paths[min_values[2]+1:end],[closed_path(новый_путь1.size+новый_путь2.size+2,new_curves)])
    end; return paths[1]
end
function calculate_Fourier_coeffs(путь::closed_path,number_of_coeffs=1024,first_coeff=0)
    ans=[]
    ς=1/2π
    f(x)=get_point_on_closed_path(путь,x)[1] - get_point_on_closed_path(путь,x)[2]*im
    for k in 1:number_of_coeffs
        isodd(k) ? k=-(k-1)÷2 : k÷=2
        g(x)=f(ς*x)*exp(-im*k*x)
        push!(ans,quadgk(g,0,2π)[1]*ς)
    end; if first_coeff==0 ans[1]=0+0im end
    return ans
end
function main()
width=4000
height=2500
println("Calculate coeffs — 1, Draw closed path — 0")
option = readline()
if option ≠ "0" && option≠"1" println("Incorrect input"); return nothing end
num_coeffs=nothing
if option=="1" 
println("number of coeffs")
num_coeffs=parse(Int,readline())
end
println("Path to svg file")
svg_file_path=readline()
d=extract_first_path_d(svg_file_path)
if isnothing(d) println("Некорретный файл") else
a=read_d_string(d)
a=connect_closed_paths(a,0.01)
if option=="1" res=calculate_Fourier_coeffs(a,num_coeffs)
writedlm("coeffs.txt", res) end
if option=="0" 
    @png begin
    origin(width/5,height/5)
    scale(6)
    background(RGB(0,0,0))
    setcolor(RGB(1,1,1))
    setline(0.9)
    draw_closed_path(a,0.001,0)
    end width height "picture.png"
end  
end

end
