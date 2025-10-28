using Plots


function ln(x)
    return ComplexF64(log(ComplexF64(x)))
end


function main()
c=[]
° = π/180
print("Every coefficient must be in seperate line. Order of coefficients is c₀,c₁,c₋₁,c₂,c₋₂,…\nPath to coefficients: ")
file_path = readline()
open(file_path, "r") do file
    for line in eachline(file)
        try
            complex_num = eval(Meta.parse(replace(line, "," => "")))
            push!(c, complex_num)
        catch e
            @warn "Некорректная строка $line"
        end
    end
end

print("Precision = ")
precision = parse(Int, readline())

print("Gif fps = ")
gif_fps = parse(Int, readline())

print("Length of gif = ")
gif_time = parse(Int, readline())

t = range(0, 2π, length = precision)
function f(t)
    res=0
    for i in eachindex(c)
        res+= c[i] * exp(im * t * (i ÷ 2) * ((-1) ^ (i % 2)))
    end
    return res
end


p = plot(real.(f.(t)), imag.(f.(t)), 
        aspect_ratio =:equal,
        legend = false,
        title = "",
        xlabel = "", ylabel = "",
        xaxis = false, yaxis = false,
        grid = false,
        background_color =:black,
        linecolor =:white,
        linewidth=3)
savefig(p, "Result.png")

anim = @animate for i in range(1,length(t),gif_time*gif_fps)
    i=Int(floor(i))
    p = plot(real.(f.(t[1:i])), imag.(f.(t[1:i])),
        aspect_ratio =:equal,
        legend = false,
        grid = false,
        xlabel = "", ylabel = "",
        xaxis = false, yaxis = false,
        background_color =:black,
        linecolor =:white,
        linewidth=2)
    
    prevDot = 0
    for ii in eachindex(c)
        ϴ = t[i] * (ii ÷ 2) * ((-1) ^ (ii % 2))
        line = [prevDot, prevDot + c[ii] * exp(im * ϴ)]
        prevDot = line[2]
        plot!(p, real.(line), imag.(line), color=:gray, linewidth=2)

        scale = abs(c[ii]) / 6 
        δ = mod2pi(imag(ln(c[ii])))
        arrow1 = [prevDot, prevDot + scale * exp(im * (δ + ϴ + 165°))]
        arrow2 = [prevDot, prevDot + scale * exp(im * (δ + ϴ - 165°))]
        plot!(p, real.(arrow1), imag.(arrow1), color=:gray, linewidth=1)
        plot!(p, real.(arrow2), imag.(arrow2), color=:gray, linewidth=1)
    end
end

gif(anim, "Animation.gif", fps = gif_fps)
end

if abspath(PROGRAM_FILE) == @__FILE__
    c = []
    main()
end